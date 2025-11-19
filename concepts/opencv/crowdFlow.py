import cv2
import numpy as np

def main():
    cap = cv2.VideoCapture("mall.mp4")

    if not cap.isOpened():
        print("Error: Could not open mall.mp4")
        return

    prev_gray = None
    frame_idx = 0

    print("frame_idx,motion_energy,mean_angle_deg,directional_coherence")

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        frame_idx += 1
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

        motion_energy = 0.0
        mean_angle_deg = 0.0
        directional_coherence = 0.0

        if prev_gray is not None:
            # --- Optical Flow ---
            flow = cv2.calcOpticalFlowFarneback(
                prev_gray, gray, None,
                pyr_scale=0.5, levels=3,
                winsize=15, iterations=3,
                poly_n=5, poly_sigma=1.2, flags=0
            )

            fx = flow[..., 0]
            fy = flow[..., 1]

            mag, ang = cv2.cartToPolar(fx, fy, angleInDegrees=True)

            # --- MOTION ENERGY ---
            motion_energy = float(mag.mean())

            # --- MEAN DIRECTION (weighted by magnitude) ---
            mag_flat = mag.flatten()
            ang_flat = ang.flatten()
            total_mag = mag_flat.sum() + 1e-6

            ang_rad = np.deg2rad(ang_flat)
            vx = np.cos(ang_rad) * mag_flat
            vy = np.sin(ang_rad) * mag_flat

            mean_vx = vx.sum() / total_mag
            mean_vy = vy.sum() / total_mag
            mean_angle_deg = float(np.rad2deg(np.arctan2(mean_vy, mean_vx)))

            # --- DIRECTIONAL COHERENCE ---
            mean_norm = np.sqrt(mean_vx**2 + mean_vy**2) + 1e-6
            dir_x = mean_vx / mean_norm
            dir_y = mean_vy / mean_norm

            motion_mask = mag_flat > 0.5  # ignore tiny motions

            if np.any(motion_mask):
                vx_sel = vx[motion_mask]
                vy_sel = vy[motion_mask]
                mag_sel = mag_flat[motion_mask] + 1e-6

                cos_theta = (vx_sel * dir_x + vy_sel * dir_y) / mag_sel
                cos_theta = np.clip(cos_theta, -1.0, 1.0)
                directional_coherence = float(np.mean(np.abs(cos_theta)))

            # --- DISPLAY FLOW ON VIDEO ---
            vis = frame.copy()
            h, w = gray.shape
            step = 20
            for y in range(0, h, step):
                for x in range(0, w, step):
                    fx_s = flow[y, x, 0]
                    fy_s = flow[y, x, 1]
                    if np.hypot(fx_s, fy_s) > 1.0:
                        cv2.arrowedLine(
                            vis,
                            (x, y),
                            (int(x + fx_s), int(y + fy_s)),
                            (0, 255, 0),
                            1,
                            tipLength=0.3
                        )
        else:
            vis = frame.copy()

        # --- TEXT OVERLAY ---
        cv2.putText(vis, f"Motion: {motion_energy:.2f}", (10, 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
        cv2.putText(vis, f"Direction: {mean_angle_deg:.1f}", (10, 60),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
        cv2.putText(vis, f"Coherence: {directional_coherence:.2f}", (10, 90),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)

        # --- PRINT JUST THE DATA ---
        print(f"{frame_idx},{motion_energy:.3f},{mean_angle_deg:.1f},{directional_coherence:.2f}")

        # --- SHOW VIDEO ---
        cv2.imshow("Crowd Flow", vis)

        prev_gray = gray

        # quit on Q
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
