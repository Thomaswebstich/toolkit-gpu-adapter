# Copyright (c) 2025 Stephen G. Pope
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.



import os
import logging

# Retrieve the API key from environment variables (make optional for better debugging on Salad)
API_KEY = os.environ.get('API_KEY')
if not API_KEY:
    logging.warning("⚠️ API_KEY environment variable is not set. Authentication will fail.")

# Storage path setting
LOCAL_STORAGE_PATH = os.environ.get('LOCAL_STORAGE_PATH', '/tmp')

# GCP environment variables
GCP_SA_CREDENTIALS = os.environ.get('GCP_SA_CREDENTIALS', '')
GCP_BUCKET_NAME = os.environ.get('GCP_BUCKET_NAME', '')

def validate_env_vars(provider):
    """ Validate the necessary environment variables for the selected storage provider """
    required_vars = {
        'GCP': ['GCP_BUCKET_NAME', 'GCP_SA_CREDENTIALS'],
        'S3': ['S3_ENDPOINT_URL', 'S3_BUCKET_NAME'],
        'S3_DO': ['S3_ENDPOINT_URL']
    }
    
    # Accept both S3_ and AWS_ prefixes for keys
    s3_access = os.getenv('S3_ACCESS_KEY') or os.getenv('AWS_ACCESS_KEY_ID')
    s3_secret = os.getenv('S3_SECRET_KEY') or os.getenv('AWS_SECRET_ACCESS_KEY')
    s3_region = os.getenv('S3_REGION') or os.getenv('S3_REGION_NAME') or os.getenv('AWS_DEFAULT_REGION')

    missing_vars = [var for var in required_vars[provider] if not os.getenv(var)]
    
    if provider in ['S3', 'S3_DO']:
        if not s3_access: missing_vars.append('S3_ACCESS_KEY / AWS_ACCESS_KEY_ID')
        if not s3_secret: missing_vars.append('S3_SECRET_KEY / AWS_SECRET_ACCESS_KEY')

    if missing_vars:
        logging.error(f"❌ Missing environment variables for {provider} storage: {', '.join(missing_vars)}")
        # We don't raise ValueError here to allow the server to start and show logs
