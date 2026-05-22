import matplotlib.pyplot as plt

def show_original(rgb):
    plt.figure(figsize=(6, 4))
    plt.title('Original Image')
    plt.imshow(rgb)
    plt.axis('off')
    plt.show()


def show_contrast_channels(contrast_channels):
    fig, axes = plt.subplots(4, 3, figsize=(15, 18))
    axes = axes.ravel()
    for idx, (name, img) in enumerate(contrast_channels.items()):
        axes[idx].imshow(img)
        axes[idx].set_title(name)
        axes[idx].axis('off')
    plt.tight_layout()
    plt.show()


def show_wbc_rbc_contrast(contrast_channels):
    wbc_contrast = contrast_channels['S Channel']
    rbc_contrast = contrast_channels['G Channel']

    plt.figure(figsize=(12, 5))
    plt.subplot(1, 2, 1)
    plt.imshow(wbc_contrast)
    plt.title('WBC Contrast Image')
    plt.axis('off')

    plt.subplot(1, 2, 2)
    plt.imshow(rbc_contrast)
    plt.title('RBC Contrast Image')
    plt.axis('off')

    plt.tight_layout()
    plt.show()


def show_rbc_wbc_clahe(rbc_img, wbc_img):
    plt.figure(figsize=(14, 6))

    plt.subplot(1, 2, 1)
    plt.imshow(rbc_img)
    plt.title('RBC Image - G Channel + CLAHE')
    plt.axis('off')

    plt.subplot(1, 2, 2)
    plt.imshow(wbc_img)
    plt.title('WBC Image - S Channel + CLAHE')
    plt.axis('off')

    plt.tight_layout()
    plt.show()


def show_wbc_pipeline(s_channel, wbc_img, wbc_blur, wbc_mask, rbc_no_wbc):
    plt.figure(figsize=(22, 5))

    plt.subplot(1, 5, 1); plt.imshow(s_channel,  cmap='gray'); plt.title('Original S Channel'); plt.axis('off')
    plt.subplot(1, 5, 2); plt.imshow(wbc_img,    cmap='gray'); plt.title('CLAHE S Channel');    plt.axis('off')
    plt.subplot(1, 5, 3); plt.imshow(wbc_blur,   cmap='gray'); plt.title('Blurred');            plt.axis('off')
    plt.subplot(1, 5, 4); plt.imshow(wbc_mask,   cmap='gray'); plt.title('WBC Mask');           plt.axis('off')
    plt.subplot(1, 5, 5); plt.imshow(rbc_no_wbc, cmap='gray'); plt.title('RBC without WBC');    plt.axis('off')

    plt.tight_layout()
    plt.show()


def show_rbc_otsu_test(rbc_no_wbc, rbc_no_wbc_blur, otsu_mask, otsu_thresh):
    plt.figure(figsize=(18, 5))

    plt.subplot(1, 3, 1); plt.imshow(rbc_no_wbc,      cmap='gray'); plt.title('RBC without WBC');                    plt.axis('off')
    plt.subplot(1, 3, 2); plt.imshow(rbc_no_wbc_blur,  cmap='gray'); plt.title('Blurred Image');                      plt.axis('off')
    plt.subplot(1, 3, 3); plt.imshow(otsu_mask,         cmap='gray'); plt.title(f'Otsu Mask (T={otsu_thresh:.2f})'); plt.axis('off')

    plt.tight_layout()
    plt.show()