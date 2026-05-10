import os
import json
import re
from pathlib import Path
from typing import Dict, List, Optional, Any

SPLITS = ("train", "val", "test")


def parse_annotation(ann_path: str) -> Dict[str, Any]:
    """
    Đọc file annotation JSON của BCCD và trả về metadata của ảnh đó.

    Args:
        ann_path (str): Đường dẫn đến file .json trong thư mục ann/

    Returns:
        dict với các khoá:
            - filename   : tên file ảnh gốc (bỏ phần '.json' ở cuối)
            - rbc_count  : số bounding box RBC (hồng cầu)
            - wbc_count  : số bounding box WBC (bạch cầu)
            - total_cells: tổng số tế bào
            - width      : chiều rộng ảnh (px)
            - height     : chiều cao ảnh (px)
            - objects    : danh sách các bounding box
                           [{'class': 'RBC'/'WBC',
                             'x1': int, 'y1': int, 'x2': int, 'y2': int}]
    """
    ann_path = Path(ann_path)

    with open(ann_path, encoding="utf-8") as f:
        data = json.load(f)

    rbc_count = 0
    wbc_count = 0
    objects = []

    for obj in data.get("objects", []):
        cls = obj.get("classTitle", "").upper()
        exterior = obj.get("points", {}).get("exterior", [])

        if len(exterior) == 2:
            x1, y1 = exterior[0]
            x2, y2 = exterior[1]
        else:
            x1 = y1 = x2 = y2 = None

        if cls == "RBC":
            rbc_count += 1
        elif cls == "WBC":
            wbc_count += 1

        objects.append({
            "class": cls,
            "x1": x1, "y1": y1,
            "x2": x2, "y2": y2,
        })

    size = data.get("size", {})

    filename = ann_path.stem

    return {
        "filename":    filename,
        "rbc_count":   rbc_count,
        "wbc_count":   wbc_count,
        "total_cells": rbc_count + wbc_count,
        "width":       size.get("width"),
        "height":      size.get("height"),
        "objects":     objects,
    }


# ──────────────────────────────────────────────────────────
#  Load toàn bộ metadata theo split
# ──────────────────────────────────────────────────────────

def load_split_metadata(dataset_path: str, split: str) -> List[Dict[str, Any]]:
    """
    Load metadata của tất cả ảnh trong một split (train / val / test).

    Args:
        dataset_path (str): Thư mục gốc của dataset, VD "C:\\Users\\...\\BCCD dataset"
        split        (str): "train", "val", hoặc "test"

    Returns:
        list[dict]: Danh sách metadata, mỗi dict thêm khoá 'split'.
    """
    split = split.lower()
    if split not in SPLITS:
        raise ValueError(f"split phải là một trong {SPLITS}, nhận được: '{split}'")

    ann_dir = Path(dataset_path) / split / "ann"
    if not ann_dir.is_dir():
        raise FileNotFoundError(f"Không tìm thấy thư mục annotation: {ann_dir}")

    metadata_list = []
    for ann_file in sorted(ann_dir.glob("*.json")):
        meta = parse_annotation(ann_file)
        meta["split"] = split
        metadata_list.append(meta)

    return metadata_list


def load_all_metadata(dataset_path: str) -> Dict[str, List[Dict[str, Any]]]:
    """
    Load metadata của toàn bộ dataset (train + val + test).

    Args:
        dataset_path (str): Thư mục gốc của dataset.

    Returns:
        dict: {"train": [...], "val": [...], "test": [...]}
              Mỗi list là danh sách metadata của split đó.
    """
    result = {}
    for split in SPLITS:
        split_dir = Path(dataset_path) / split / "ann"
        if not split_dir.is_dir():
            print(f"[WARN] Không tìm thấy split '{split}', bỏ qua.")
            result[split] = []
            continue
        result[split] = load_split_metadata(dataset_path, split)

    return result


# ──────────────────────────────────────────────────────────
#  Thống kê
# ──────────────────────────────────────────────────────────

def get_statistics(metadata_list: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Tính thống kê từ danh sách metadata (có thể của 1 split hoặc gộp nhiều split).

    Returns:
        dict:
            - total_images
            - total_rbc / total_wbc / total_cells
            - avg_rbc / avg_wbc (trung bình trên mỗi ảnh)
            - max_rbc / max_wbc
            - min_rbc / min_wbc
    """
    if not metadata_list:
        return {}

    total_rbc = sum(m["rbc_count"] for m in metadata_list)
    total_wbc = sum(m["wbc_count"] for m in metadata_list)
    n = len(metadata_list)

    return {
        "total_images":  n,
        "total_rbc":     total_rbc,
        "total_wbc":     total_wbc,
        "total_cells":   total_rbc + total_wbc,
        "avg_rbc":       round(total_rbc / n, 2),
        "avg_wbc":       round(total_wbc / n, 2),
        "max_rbc":       max(m["rbc_count"] for m in metadata_list),
        "max_wbc":       max(m["wbc_count"] for m in metadata_list),
        "min_rbc":       min(m["rbc_count"] for m in metadata_list),
        "min_wbc":       min(m["wbc_count"] for m in metadata_list),
    }


def get_full_statistics(all_metadata: Dict[str, List]) -> Dict[str, Any]:
    """
    Tính thống kê cho từng split và tổng thể.

    Args:
        all_metadata: output của load_all_metadata()

    Returns:
        dict: {"train": {...}, "val": {...}, "test": {...}, "overall": {...}}
    """
    result = {}
    combined = []
    for split, mlist in all_metadata.items():
        result[split] = get_statistics(mlist)
        combined.extend(mlist)
    result["overall"] = get_statistics(combined)
    return result


# ──────────────────────────────────────────────────────────
#  Lưu / lọc
# ──────────────────────────────────────────────────────────

def save_metadata_to_json(metadata_list: List[Dict], output_file: str) -> None:
    """Lưu danh sách metadata ra file JSON (không lưu objects để gọn file)."""
    slim = []
    for m in metadata_list:
        entry = {k: v for k, v in m.items() if k != "objects"}
        slim.append(entry)

    out = Path(output_file)
    out.parent.mkdir(parents=True, exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        json.dump(slim, f, indent=4, ensure_ascii=False)
    print(f"Đã lưu metadata tại: {out.resolve()}")


def filter_by_class_count(metadata_list: List[Dict],
                           cell_class: str,
                           min_count: int = 0,
                           max_count: int = 9999) -> List[Dict]:
    """
    Lọc ảnh theo số lượng tế bào của một loại.

    Args:
        cell_class : "RBC" hoặc "WBC"
        min_count  : ngưỡng tối thiểu (inclusive)
        max_count  : ngưỡng tối đa   (inclusive)
    """
    key = f"{cell_class.lower()}_count"
    return [m for m in metadata_list if min_count <= m.get(key, 0) <= max_count]


# ──────────────────────────────────────────────────────────
#  Main – kiểm tra nhanh
# ──────────────────────────────────────────────────────────

if __name__ == "__main__":
    DATASET_PATH = r"C:\Users\ASUS\Downloads\BCCD dataset"
    JSON_OUTPUT  = os.path.join("data", "metadata.json")

    print(f"=== Đang đọc dataset từ: {DATASET_PATH} ===\n")

    # 1. Load toàn bộ metadata
    all_metadata = load_all_metadata(DATASET_PATH)

    # 2. In thống kê từng split
    stats = get_full_statistics(all_metadata)
    for split in (*SPLITS, "overall"):
        s = stats.get(split, {})
        if not s:
            continue
        print(f"[{split.upper()}]")
        print(f"  Số ảnh     : {s.get('total_images', 0)}")
        print(f"  Tổng RBC   : {s.get('total_rbc', 0)}  (TB/ảnh: {s.get('avg_rbc', 0)})")
        print(f"  Tổng WBC   : {s.get('total_wbc', 0)}  (TB/ảnh: {s.get('avg_wbc', 0)})")
        print(f"  Tổng cells : {s.get('total_cells', 0)}")
        print()

    # 3. In mẫu metadata đầu tiên của test
    test_list = all_metadata.get("test", [])
    if test_list:
        print("=== Mẫu metadata đầu tiên (test split) ===")
        sample = {k: v for k, v in test_list[0].items() if k != "objects"}
        for k, v in sample.items():
            print(f"  {k}: {v}")

    # 4. Lưu metadata (gộp tất cả split) ra JSON
    combined = []
    for mlist in all_metadata.values():
        combined.extend(mlist)
    save_metadata_to_json(combined, JSON_OUTPUT)

    # 5. Ví dụ lọc – ảnh trong test có ≥ 10 RBC
    high_rbc = filter_by_class_count(test_list, "RBC", min_count=10)
    print(f"\nSố ảnh test có ≥ 10 RBC: {len(high_rbc)}")