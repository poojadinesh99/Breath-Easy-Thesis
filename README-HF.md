# Hugging Face deployment configuration
model_name: "thesis-app-deployment"
tags:
  - "breath-analysis"
  - "fastapi"
  - "respiratory"

# Runtime configuration
python_version: "3.10"
sdk: "gradio"
sdk_version: "3.50.2"

# App configuration
app_file: "app.py"
app_port: 7860
