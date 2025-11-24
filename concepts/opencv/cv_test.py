import cv2
import numpy as np
from pythonosc import udp_client

# ----------------------------------------
# OSC SETTINGS
# ----------------------------------------
OSC_IP = "127.0.0.1"
OSC_PORT = 9000
OSC_ADDRESS = "/motion"

client = udp_client.SimpleUDPClient(OSC_IP, OSC_PORT)

# ----------------------------------------import cv2
import numpy as np
from pythonosc import udp_client

# ----------------------------------------
# OSC SETTINGS
# ----------------------------------------
OSC_IP = "127.0.0.1"
OSC_PORT = 9000
OSC_ADDRESS = "/motion"

client = udp_client.SimpleUDPClient(OSC_IP, OSC_PORT)

# ----------------------------------------
# VIDEO CAPTURE & BACKGROUND MODEL
# ----------------------------------------
cap = cv2.VideoCapture(0)
backsub = cv2.createBackgroundSubtractorMOG2(history=300, varThreshold=40)

print("Motion highlighting + normalized OSC output. Press 'q' to exit.")

while True:
    ret, frame = cap.read()
    if not ret:
        break

    frame = cv2.resize(frame, (640, 480))
    frame =cv2.flip(frame,1)
    h, w = frame.shape[:2]

    # ----------------------------------------
    # MOTION MASK
    # ----------------------------------------
    mask = backsub.apply(frame)

    # Clean mask
    _, mask = cv2.threshold(mask, 200, 255, cv2.THRESH_BINARY)
    mask = cv2.medianBlur(mask, 11)
    mask = cv2.dilate(mask, None, iterations=2)

    # Find all motion contours
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    motion_cx, motion_cy = None, None

    # ----------------------------------------
    # COMBINE ALL MOTION AREAS
    # ----------------------------------------
    if contours:
        # Merge all contours into one "motion region"
        all_pts = np.vstack(contours)
        x, y, ww, hh = cv2.boundingRect(all_pts)

        # Compute center of motion
        motion_cx = int(x + ww / 2)
        motion_cy = int(y + hh / 2)

        # Normalize
        norm_x = motion_cx / w
        norm_y = motion_cy / h

        # Send OSC
        client.send_message(OSC_ADDRESS, [float(norm_x), float(norm_y)])

    # -----------------------------------------------------
    # ARTSY MOTION HIGHLIGHT (GLOW + COLOR WARP)
    # -----------------------------------------------------

    # Background aesthetic filter (slightly posterized)
    blurred = cv2.GaussianBlur(frame, (13, 13), 0)
    poster = (blurred // 32) * 32

    # Make a glowing motion mask
    glow = cv2.GaussianBlur(mask, (51, 51), 0)
    glow_f = glow.astype(float) / 255.0
    glow_f = np.repeat(glow_f[:, :, np.newaxis], 3, axis=2)

    # Neon version of frame
    hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
    hsv[:, :, 1] = cv2.add(hsv[:, :, 1], 90)  # saturation boost
    hsv[:, :, 2] = cv2.add(hsv[:, :, 2], 70)  # brightness boost
    neon = cv2.cvtColor(hsv, cv2.COLOR_HSV2BGR)

    # Blend neon where motion is
    result = (poster * (1 - glow_f) + neon * glow_f).astype(np.uint8)

    # Draw center marker
    if motion_cx is not None:
        cv2.circle(result, (motion_cx, motion_cy), 12, (0, 255, 255), 2)
        cv2.putText(result, f"{norm_x:.2f}, {norm_y:.2f}",
                    (motion_cx + 10, motion_cy - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)

    # Slight film grain
    noise = np.random.normal(0, 10, frame.shape).astype(np.int16)
    result = np.clip(result.astype(np.int16) + noise, 0, 255).astype(np.uint8)

    cv2.imshow("Motion Highlight + OSC", result)
    cv2.imshow("Motion Mask", mask)  # optional debug window

    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()

# VIDEO CAPTURE & BACKGROUND MODEL
# ----------------------------------------
cap = cv2.VideoCapture(0)
backsub = cv2.createBackgroundSubtractorMOG2(history=300, varThreshold=40)

print("Motion highlighting + normalized OSC output. Press 'q' to exit.")

while True:
    ret, frame = cap.read()
    if not ret:
        break

    frame = cv2.resize(frame, (640, 480))
    h, w = frame.shape[:2]

    # ----------------------------------------
    # MOTION MASK
    # ----------------------------------------
    mask = backsub.apply(frame)

    # Clean mask
    _, mask = cv2.threshold(mask, 200, 255, cv2.THRESH_BINARY)
    mask = cv2.medianBlur(mask, 11)
    mask = cv2.dilate(mask, None, iterations=2)

    # Find all motion contours
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    motion_cx, motion_cy = None, None

    # ----------------------------------------
    # COMBINE ALL MOTION AREAS
    # ----------------------------------------
    if contours:
        # Merge all contours into one "motion region"
        all_pts = np.vstack(contours)
        x, y, ww, hh = cv2.boundingRect(all_pts)

        # Compute center of motion
        motion_cx = int(x + ww / 2)
        motion_cy = int(y + hh / 2)

        # Normalize
        norm_x = motion_cx / w
        norm_y = motion_cy / h

        # Send OSC
        client.send_message(OSC_ADDRESS, [float(norm_x), float(norm_y)])

    # -----------------------------------------------------
    # ARTSY MOTION HIGHLIGHT (GLOW + COLOR WARP)
    # -----------------------------------------------------

    # Background aesthetic filter (slightly posterized)
    blurred = cv2.GaussianBlur(frame, (13, 13), 0)
    poster = (blurred // 32) * 32

    # Make a glowing motion mask
    glow = cv2.GaussianBlur(mask, (51, 51), 0)
    glow_f = glow.astype(float) / 255.0
    glow_f = np.repeat(glow_f[:, :, np.newaxis], 3, axis=2)

    # Neon version of frame
    hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
    hsv[:, :, 1] = cv2.add(hsv[:, :, 1], 90)  # saturation boost
    hsv[:, :, 2] = cv2.add(hsv[:, :, 2], 70)  # brightness boost
    neon = cv2.cvtColor(hsv, cv2.COLOR_HSV2BGR)

    # Blend neon where motion is
    result = (poster * (1 - glow_f) + neon * glow_f).astype(np.uint8)

    # Draw center marker
    if motion_cx is not None:
        cv2.circle(result, (motion_cx, motion_cy), 12, (0, 255, 255), 2)
        cv2.putText(result, f"{norm_x:.2f}, {norm_y:.2f}",
                    (motion_cx + 10, motion_cy - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)

    # Slight film grain
    noise = np.random.normal(0, 10, frame.shape).astype(np.int16)
    result = np.clip(result.astype(np.int16) + noise, 0, 255).astype(np.uint8)

    cv2.imshow("Motion Highlight + OSC", result)
    cv2.imshow("Motion Mask", mask)  # optional debug window

    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
