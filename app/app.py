import streamlit as st
import tempfile
from src import pipeline
from src.pipeline import UNET_MODEL, YOLO_MODEL


st.set_page_config(page_title="Cell Counting App", layout="wide")
st.title("🔬 CCA")

# --- Sidebar ---
model_choice = st.sidebar.selectbox("Select model", ["Unet", "YOLOv8"])

preprocess_method = None
min_cell_size = None

if model_choice == "Unet":
    preprocess_method = st.sidebar.selectbox(
        "Select preprocessing method",
        ["sobel", "clahe", "gaussian", "raw"]
    )
    min_cell_size = st.sidebar.slider(
        "Minimum cell size (pixels)",
        min_value=1, max_value=200, value=10, step=1
    )

uploaded_file = st.file_uploader("Upload cell image", type=["jpg", "png", "jpeg"])

if uploaded_file:
    tfile = tempfile.NamedTemporaryFile(delete=False)
    tfile.write(uploaded_file.read())

    if model_choice == "Unet":
        orig, overlay, count = pipeline.run_unet(
            tfile.name,
            method=preprocess_method,
            min_size=min_cell_size
        )
    else:
        orig, overlay, count = pipeline.run_yolo(tfile.name)

    col1, col2 = st.columns(2)

    with col1:
        st.markdown("<h3 style='text-align:center;'>Original Image</h3>", unsafe_allow_html=True)
        st.image(orig, use_container_width=True)

    with col2:
        st.markdown(f"<h3 style='text-align:center;'>{count} cells</h3>", unsafe_allow_html=True)
        st.image(overlay, use_container_width=True)
