from typing import Any, Dict, List, Optional, Tuple
import numpy as np
import pandas as pd
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
)

def evaluate_classification_model(
    y_true: List[str],
    y_pred: List[str],
    classes: Optional[List[str]] = None
) -> Dict[str, Any]:
    """
    Computes comprehensive classification metrics conforming to PRD Section 39.
    """
    if classes is None:
        classes = sorted(list(set(y_true) | set(y_pred)))

    acc = float(accuracy_score(y_true, y_pred))
    macro_f1 = float(f1_score(y_true, y_pred, average="macro", zero_division=0))
    weighted_f1 = float(f1_score(y_true, y_pred, average="weighted", zero_division=0))
    macro_prec = float(precision_score(y_true, y_pred, average="macro", zero_division=0))
    macro_rec = float(recall_score(y_true, y_pred, average="macro", zero_division=0))

    cm = confusion_matrix(y_true, y_pred, labels=classes)
    report_dict = classification_report(y_true, y_pred, labels=classes, output_dict=True, zero_division=0)

    return {
        "accuracy": round(acc, 4),
        "accuracy_percentage": f"{acc * 100:.2f}%",
        "macro_f1": round(macro_f1, 4),
        "weighted_f1": round(weighted_f1, 4),
        "macro_precision": round(macro_prec, 4),
        "macro_recall": round(macro_rec, 4),
        "classes": classes,
        "confusion_matrix": cm.tolist(),
        "classification_report": report_dict,
        "sample_count": len(y_true)
    }


def evaluate_forecast_predictions(y_true: List[float], y_pred: List[float]) -> Dict[str, float]:
    """
    Computes forecast error metrics (MAE, RMSE, MAPE) conforming to PRD Section 40.
    """
    yt = np.array(y_true, dtype=float)
    yp = np.array(y_pred, dtype=float)

    mae = float(np.mean(np.abs(yt - yp)))
    rmse = float(np.sqrt(np.mean((yt - yp) ** 2)))
    
    # Avoid division by zero in MAPE
    non_zero = yt != 0
    if np.any(non_zero):
        mape = float(np.mean(np.abs((yt[non_zero] - yp[non_zero]) / yt[non_zero])) * 100.0)
    else:
        mape = 0.0

    return {
        "mae": round(mae, 2),
        "rmse": round(rmse, 2),
        "mape": round(mape, 2)
    }
