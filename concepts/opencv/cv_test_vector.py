import cv2
import numpy as np
from pythonosc import udp_client
import math
import socket

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

device_ip = get_ip().replace(".", "_")  # replace dots for OSC compatibility

# ----------------------------------------
# OSC SETTINGS
# ----------------------------------------
OSC_IP_1 = "10.10.10.19"

OSC_IP_2 = "10.10.10.20"

OSC_IP_3 = "10.10.10.21"


OSC_PORT = 9001
OSC_ADDRESS = "/motion" + device_ip    #format /motionDEVICEIP

client_1 = udp_client.SimpleUDPClient(OSC_IP_1, OSC_PORT)
client_2 = udp_client.SimpleUDPClient(OSC_IP_2, OSC_PORT)
client_3 = udp_client.SimpleUDPClient(OSC_IP_3, OSC_PORT)

# ----------------------------------------
# VIDEO CAPTURE & BACKGROUND MODEL
# ----------------------------------------
cap = cv2.VideoCapture(0)
backsub = cv2.createBackgroundSubtractorMOG2(history=300, varThreshold=40)

print("Motion entropy + vector field. Press 'q' to exit.")

# Optical flow state
prev_gray = None
step = 8  # how many frames between new vectors lower frames is more dense

while True:
    ret, frame = cap.read()
    if not ret:
        break

    frame = cv2.resize(frame, (640, 480))
    frame = cv2.flip(frame, 1)
    h, w = frame.shape[:2]
    total_pixels = w * h

    # ----------------------------------------
    # CURRENT GRAYSCALE FRAME
    # ----------------------------------------
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

    # Initialize previous frame
    if prev_gray is None:
        prev_gray = gray
        continue

    # ----------------------------------------
    # MOTION MASK
    # ----------------------------------------
    mask = backsub.apply(frame)

    _, mask = cv2.threshold(mask, 200, 255, cv2.THRESH_BINARY)
    mask = cv2.medianBlur(mask, 11)
    mask = cv2.dilate(mask, None, iterations=2)

    # Count motion pixels
    motion_pixels = np.count_nonzero(mask)

    # ----------------------------------------
    # ENTROPY METRIC
    # ----------------------------------------
    p = motion_pixels / float(total_pixels)
    entropy = -p * math.log(p) * 2 if p > 0 else 0.0

    # Send entropy via OSC
    client_1.send_message(OSC_ADDRESS, float(entropy))
    client_2.send_message(OSC_ADDRESS, float(entropy))
    client_3.send_message(OSC_ADDRESS, float(entropy))

    # ----------------------------------------
    # OPTICAL FLOW (VECTOR FIELD)
    # ----------------------------------------
    flow = cv2.calcOpticalFlowFarneback(
        prev_gray, gray,
        None,
        0.5,    # pyr_scale
        3,      # levels
        15,     # winsize
        3,      # iterations
        5,      # poly_n
        1.2,    # poly_sigma
        0
    )

    prev_gray = gray  # update for next frame

    img = np.zeros((512, 512, 3), np.uint8)

    # ----------------------------------------
    # DRAW ENTROPY TEXT
    # ----------------------------------------
    cv2.putText(img,                                #change to mask
                f"entropy: {entropy:.4f}",
                (20, 40),
                cv2.FONT_HERSHEY_SIMPLEX,
                1.0,
                (255),
                2)

    # ----------------------------------------
    # DRAW VECTOR FIELD ON MASK
    # ----------------------------------------
    for y in range(0, h, step):
        for x in range(0, w, step):

            # Only draw arrows where motion exists
            if mask[y, x] < 128:
                continue

            fx, fy = flow[y, x]

            end_x = int(x + fx * 5)
            end_y = int(y + fy * 5)

            cv2.arrowedLine(
                img,
                (x, y),
                (end_x, end_y),
                (255,255,255),   # grayscale for mask view
                1,
                tipLength=0.4
            )

    # ----------------------------------------
    # SHOW MASK
    # ----------------------------------------
    cv2.imshow("Motion Mask", img)  #or draw on mask not on img

    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
