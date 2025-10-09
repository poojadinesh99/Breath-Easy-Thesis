
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

def generate_text_summary(label: str, confidence: float) -> str:
    """
    Generates a human-readable summary of the analysis results.
    
    This function is important for the thesis as it translates the raw
    probabilistic output of the model into an understandable and actionable
    insight, which is a key aspect of user-centered AI design.
    
    Args:
        label (str): The predicted label (e.g., 'clear', 'wheezing').
        confidence (float): The model's confidence in the prediction (0.0 to 1.0).
        
    Returns:
        str: A user-friendly text summary.
    """
    label_lower = label.lower()
    confidence_percent = confidence * 100

    if label_lower in ["clear", "normal"]:
        if confidence > 0.85:
            return (f"The analysis indicates clear breathing with high confidence ({confidence_percent:.1f}%). "
                    "No significant abnormal patterns were detected in the audio sample.")
        else:
            return (f"The analysis suggests the breathing is likely clear ({confidence_percent:.1f}% confidence). "
                    "While no major anomalies were found, the signal was not perfectly clean.")
    else:
        if confidence > 0.9:
            return (f"The analysis has detected sounds characteristic of **{label}** with very high confidence ({confidence_percent:.1f}%). "
                    "This is a strong indicator and should be reviewed by a healthcare professional.")
        elif confidence > 0.7:
            return (f"The analysis suggests the presence of **{label}** with a confidence of {confidence_percent:.1f}%. "
                    "It is recommended to consult a doctor for a formal diagnosis.")
        else:
            return (f"There are some indications of **{label}** ({confidence_percent:.1f}% confidence), but the signal is not definitive. "
                    "Monitoring and a potential follow-up are advised.")

    return "Analysis complete. Please review the detailed results."
