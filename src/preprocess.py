import cv2
import numpy as np

# =========================
# Image loading
# =========================
def load_image(path):
    bgr = cv2.imread(path)
    rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
    return rgb

# =========================
# Color space conversion
# =========================
def extract_channels(rgb):
    hsv   = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    lab   = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB)
    ycrcb = cv2.cvtColor(rgb, cv2.COLOR_RGB2YCrCb)

    channels = {
        # RGB
        'R Channel': rgb[:, :, 0],
        'G Channel': rgb[:, :, 1],
        'B Channel': rgb[:, :, 2],
        # HSV
        'H Channel': hsv[:, :, 0],
        'S Channel': hsv[:, :, 1],
        'V Channel': hsv[:, :, 2],
        # LAB
        'L Channel': lab[:, :, 0],
        'A Channel': lab[:, :, 1],
        'B* Channel': lab[:, :, 2],
        # YCrCb
        'Y Channel':  ycrcb[:, :, 0],
        'Cr Channel': ycrcb[:, :, 1],
        'Cb Channel': ycrcb[:, :, 2],
    }
    return channels, hsv

# =========================
# Contrast enhancement
# =========================
def apply_clahe(img, clip=2.0, grid=(8, 8)):
    clahe = cv2.createCLAHE(clipLimit=clip, tileGridSize=grid)
    return clahe.apply(img)


def enhance_contrast_all(channels):
    return {name: apply_clahe(ch) for name, ch in channels.items()}

# =========================
# RBC preprocessing
# =========================
def preprocess_rbc(rgb):
    g_channel = rgb[:, :, 1]
    rbc_img   = apply_clahe(g_channel)
    rbc_blur  = cv2.GaussianBlur(rbc_img, (5, 5), 0)
    return rbc_img, rbc_blur


# =========================
# WBC preprocessing
# =========================
def preprocess_wbc(hsv):
    s_channel = hsv[:, :, 1]
    wbc_img   = apply_clahe(s_channel)
    wbc_blur  = cv2.GaussianBlur(wbc_img, (5, 5), 0)
    return s_channel, wbc_img, wbc_blur


# =========================
# WBC mask
# =========================
def create_wbc_mask(wbc_blur):
    mean_val      = np.mean(wbc_blur)
    std_val       = np.std(wbc_blur)
    bright_thresh = mean_val + 1.9 * std_val

    _, wbc_mask = cv2.threshold(wbc_blur, bright_thresh, 255, cv2.THRESH_BINARY)

    kernel  = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    wbc_mask = cv2.morphologyEx(wbc_mask, cv2.MORPH_OPEN,  kernel)
    wbc_mask = cv2.morphologyEx(wbc_mask, cv2.MORPH_CLOSE, kernel)

    print(f"Mean intensity : {mean_val:.2f}")
    print(f"Std intensity  : {std_val:.2f}")
    print(f"Threshold used : {bright_thresh:.2f}")

    return wbc_mask


# =========================
# Remove WBC from RBC image
# =========================
def remove_wbc_from_rbc(rbc_img, wbc_mask):
    rbc_no_wbc = rbc_img.copy()
    rbc_no_wbc[wbc_mask > 0] = 0
    return rbc_no_wbc


# =========================
# RBC Otsu mask
# =========================
def create_rbc_otsu_mask(rbc_no_wbc, wbc_mask):
    rbc_no_wbc_blur = cv2.GaussianBlur(rbc_no_wbc, (5, 5), 0)

    otsu_thresh, otsu_mask = cv2.threshold(
        rbc_no_wbc_blur, 0, 255,
        cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU
    )
    otsu_mask[wbc_mask > 0] = 0

    kernel    = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    otsu_mask = cv2.morphologyEx(otsu_mask, cv2.MORPH_OPEN,  kernel)
    otsu_mask = cv2.morphologyEx(otsu_mask, cv2.MORPH_CLOSE, kernel)

    print(f"Otsu Threshold Value: {otsu_thresh:.2f}")

    return rbc_no_wbc_blur, otsu_thresh, otsu_mask