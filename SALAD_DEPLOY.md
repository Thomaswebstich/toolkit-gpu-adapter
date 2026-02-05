# Deployment Guide for Salad Cloud

This guide explains how to deploy the GPU-optimized No-Code Architects Toolkit to Salad Cloud.

## Prerequisites

1.  **Docker Desktop** (or Docker Engine) installed and running.
2.  **Salad Cloud Account**.
3.  **Container Registry Account** (Docker Hub, GitHub Container Registry, etc.).

## 1. Build the Docker Image

### Option A: GitHub Actions (Recommended for older machines)
Since your local machine might not support Docker Desktop, use GitHub Actions to build the image in the cloud.

1.  Commit and push your changes to GitHub.
2.  Go to the **Actions** tab in your repository.
3.  Select **Build and Push Docker Image**.
4.  Click **Run workflow**.
5.  Once complete, your image will be available at `ghcr.io/your-github-username/no-code-architects-toolkit:latest`.

**Note:** You will need to make the package "Public" in your GitHub Package settings if you want Salad to pull it without authentication, or provide Salad with a Personal Access Token (PAT).

### Option B: Local Build (Docker Desktop)
If you have Docker Desktop installed:

```bash
# Replace 'your-username' with your Docker Hub username
docker build --platform linux/amd64 -t ghcr.io/thomaswebstich/toolkit-gpu-adapter:latest .
```

## 2. Push to Registry

Push the built image to your public or private registry.

```bash
docker push your-username/nca-toolkit-gpu:latest
```

## 3. Deploy on Salad Cloud

1.  Log in to the [Salad Portal](https://portal.salad.com/).
2.  Create a new **Container Group**.
3.  **Configure Image:**
    *   **Image Source:** `ghcr.io/thomaswebstich/toolkit-gpu-adapter:latest`
    *   **Replica Count:** 1 (start with 1 for testing)
4.  **Resources:**
    *   **CPU:** 2 vCPU (recommended)
    *   **RAM:** 8 GB or 12 GB (Whisper models need RAM)
    *   **GPU:** Select a GPU class (e.g., RTX 3060, RTX 3080, or RTX 4090). 
        > [!IMPORTANT]
        > Ensure you select a GPU node. Without a GPU, the application will fallback to CPU but will be slow.
5.  **Networking:**
    *   **Port:** `8080` (The application listens on port 8080)
    *   **Protocol:** HTTP
    *   **Authentication:** Enable if you want to protect your endpoint (Recommended).
6.  **Environment Variables:**
    *   `GUNICORN_WORKERS`: `1` (Recommended to set to 1 on GPU)
    *   `GUNICORN_TIMEOUT`: `3600` (Increase Gunicorn timeout to match script timeout)
    *   `PYTHON_EXECUTE_TIMEOUT`: `3600` (Timeout for Python scripts in seconds)
    *   `AWS_ACCESS_KEY_ID`: `WSY9GSCA4RCVXB4LL53C`
    *   `AWS_SECRET_ACCESS_KEY`: `AcGFeq6VP4PoRWUCPHmQ3wj8vSre8sChqpPAbzRc`
    *   `S3_ENDPOINT_URL`: `https://fsn1.your-objectstorage.com`
    *   `S3_BUCKET_NAME`: `narrated`
    *   `S3_REGION_NAME`: `us-east-1` (or your specific region if known, otherwise default)
7.  **Health Check (Optional but Recommended):**
    *   **Protocol:** TCP
    *   **Port:** 8080
    *   **Path:** `/` (or check logs for a specific health endpoint)
    *   *Note: The app needs some time to load the model on startup.*

## 4. Testing

Once the container is "Running":

1.  Get the **Access Domain Name** from the Salad dashboard (e.g., `https://your-app.salad.cloud`).
2.  Send a test request:

```bash
curl -X POST https://your-app.salad.cloud/transcribe \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://example.com/sample-audio.mp3",
    "type": "transcript"
  }'
```

Check the Container Logs in Salad Portal. You should see:
`INFO:services.transcription:Loading Whisper model on device: cuda`

## Troubleshooting

*   **OOM (Out of Memory):** If the container crashes on startup, try increasing the RAM allocation (system RAM, not VRAM).
*   **Slow Transcription:** Verify in the logs that `device: cuda` is being used. If it says `device: cpu`, the container might not have access to the GPU (check Resource settings).
