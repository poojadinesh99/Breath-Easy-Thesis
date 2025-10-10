from setuptools import setup, find_packages

setup(
    name="breath-easy-backend",
    version="1.0.0",
    packages=find_packages(),
    install_requires=[
        "fastapi",
        "uvicorn",
        "python-multipart",
        "pydantic",
        "pydantic-settings",
    ],
)
