import cv2

# 1. Create a VideoCapture object
# Use 0 for the default camera. For other cameras, try 1, 2, etc.
cap = cv2.VideoCapture(0)

# Check if the camera opened successfully
if not cap.isOpened():
    print("Error: Could not open camera.")
    exit()

# 2. Start a loop to capture and display frames
while True:
    # Read a frame from the camera
    # 'ret' is a boolean indicating if the frame was read successfully
    # 'frame' is the actual image data (a NumPy array)
    ret, frame = cap.read()

    # If the frame was not read successfully, break the loop
    if not ret:
        print("Error: Can't receive frame (stream end?). Exiting ...")
        break

    # 3. Display the frame in a window
    cv2.imshow('Camera Feed', frame)

    # 4. Wait for a key press
    # If the 'q' key is pressed, break the loop
    # cv2.waitKey(1) waits for 1 millisecond. The loop will continue if no key is pressed.
    if cv2.waitKey(1) == ord('q'):
        break

# 5. Release the camera and close all windows
cap.release()
cv2.destroyAllWindows()
