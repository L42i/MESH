import cv2
import numpy as np
from pythonosc import udp_client
import math
import socket
from screeninfo import get_monitors  

# Detect primary monitor resolution
monitor = get_monitors()[0]
screen_w, screen_h = monitor.width, monitor.height

def map_range(value, input_start, input_end, output_start, output_end):
    """
    Maps a value from one range to another.
    """
    input_span = input_end - input_start
    output_span = output_end - output_start

    if input_span == 0:
        return output_start

    value_scaled = float(value - input_start) / float(input_span)
    return output_start + (value_scaled * output_span)

# Get device IP
def get_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
    except Exception:
        ip = "127.0.0.1"
    finally:
        s.close()
    return ip

device_ip = get_ip().replace(".", "_")

# ==========================
# OSC SETTINGS
# ==========================

# Bees
OSC_IPS = ["10.10.10.19", "10.10.10.20", "10.10.10.21"]
OSC_PORT = 9001
OSC_ADDRESS = "/motion" + device_ip
clients = [udp_client.SimpleUDPClient(ip, OSC_PORT) for ip in OSC_IPS]

# Local SuperCollider
SC_IP = "127.0.0.1"
SC_PORT = 57120          # default SuperCollider port
SC_ADDRESS = "/entropy"  # address SC will listen to

sc_client = udp_client.SimpleUDPClient(SC_IP, SC_PORT)

# VIDEO CAPTURE & BACKGROUND MODEL
cap = cv2.VideoCapture(0)
backsub = cv2.createBackgroundSubtractorMOG2(history=300, varThreshold=40)

prev_gray = None
step = 8  # optical flow sampling step

# ------- SOUND BANK STATE -------
NUM_SOUNDS = 8
sound_index = 0          # 0..7, but we print 1..8.wav
ENTROPY_THRESHOLD = 0.5
ready_for_trigger = True  # hysteresis flag

# Normal window (NOT fullscreen)
cv2.namedWindow("Motion Mask", cv2.WINDOW_NORMAL)
cv2.setWindowProperty("Motion Mask", cv2.WND_PROP_FULLSCREEN, cv2.WINDOW_FULLSCREEN)


print("Motion entropy + vector field. Press 'q' to exit.")

while True:
    ret, frame = cap.read()
    if not ret:
        break

    frame = cv2.flip(frame, 1)
    h, w = frame.shape[:2]
    total_pixels = w * h

    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    if prev_gray is None:
        prev_gray = gray
        continue

    # Motion mask
    mask = backsub.apply(frame)
    _, mask = cv2.threshold(mask, 200, 255, cv2.THRESH_BINARY)

    motion_pixels = np.count_nonzero(mask)

    # Entropy
    p = motion_pixels / float(total_pixels)
    entropy = -p * math.log(p) * 2 if p > 0 else 0.0

    # ------- ENTROPY → SOUND BANK TRIGGER -------
    if entropy >= ENTROPY_THRESHOLD and ready_for_trigger:
        # advance sound index, wrap at NUM_SOUNDS
        sound_index = (sound_index + 1) % NUM_SOUNDS
        # print which sound would play (1.wav .. 8.wav)
        print(f"{sound_index + 1}.wav")
        # disarm until entropy drops below threshold
        ready_for_trigger = False
    elif entropy < ENTROPY_THRESHOLD:
        # re-arm once entropy is back below threshold
        ready_for_trigger = True

        # (if you want "stop playing sound" behavior back, re-add it here)

    # ----------------------------
    # Send OSC entropy
    # ----------------------------

    # To bees
    for client in clients:
        client.send_message(OSC_ADDRESS, float(entropy))

    # To local SuperCollider
    sc_client.send_message(SC_ADDRESS, float(entropy))

    # Optical flow
    flow = cv2.calcOpticalFlowFarneback(
        prev_gray, gray, None,
        0.5, 3, 15, 3, 5, 1.2, 0
    )
    prev_gray = gray

    # Visualization canvas
    img = np.zeros_like(frame)
    cv2.putText(img,
                f"Entropy: {entropy:.4f}",
                (20, 40),
                cv2.FONT_HERSHEY_SIMPLEX,
                1.0,
                (255, 255, 255),
                2)

    # Draw optical flow arrows
    for y in range(0, h, step):
        for x in range(0, w, step):
            if mask[y, x] < 128:
                continue
            fx, fy = flow[y, x]
            end_x = int(x + fx * 5)
            end_y = int(y + fy * 5)

            radians = math.atan2(fy, fx)
            degrees = abs(math.degrees(radians))

            mapped_val = map_range(int(degrees), 0, 360, 0, 255)
            hsv_color = np.uint8([[[int(mapped_val), 180 + math.sin(mapped_val)*180/(2*np.pi), 255]]])
            bgr_color = cv2.cvtColor(hsv_color, cv2.COLOR_HSV2BGR)[0][0]

            r = int(bgr_color[0])
            b = int(bgr_color[1])
            g = int(bgr_color[2])

            cv2.arrowedLine(img,
                            (x, y),
                            (end_x, end_y),
                            (b, g, r),
                            1,
                            tipLength=0.4)

    new_w = screen_w
    new_h = screen_h

    img_resized = cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_LINEAR)

    # Black canvas and center the image
    canvas = np.zeros((screen_h, screen_w, 3), dtype=np.uint8)
    x_offset = (screen_w - new_w) // 2
    y_offset = (screen_h - new_h) // 2
    canvas[y_offset:y_offset+new_h, x_offset:x_offset+new_w] = img_resized

    cv2.imshow("Motion Mask", canvas)

    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
