#!/usr/bin/env python3
import os
import sys
import glob
import json

def upload():
    creds_json = os.environ.get("GDRIVE_SERVICE_ACCOUNT_KEY")
    folder_id = os.environ.get("GDRIVE_FOLDER_ID")

    if not creds_json or not folder_id:
        print("⚠️ GDRIVE_SERVICE_ACCOUNT_KEY or GDRIVE_FOLDER_ID is not configured.")
        print("ℹ️ Skipping Google Drive upload. (Configure repository secrets to enable)")
        return

    pkg_files = glob.glob("dist/*.pkg")
    if not pkg_files:
        print("❌ No .pkg file found in dist/")
        sys.exit(1)

    pkg_path = sorted(pkg_files, key=os.path.getmtime, reverse=True)[0]
    pkg_name = os.path.basename(pkg_path)
    file_size_mb = os.path.getsize(pkg_path) / (1024 * 1024)

    print(f"📦 Target PKG: {pkg_name} ({file_size_mb:.2f} MB)")

    try:
        from google.oauth2 import service_account
        from googleapiclient.discovery import build
        from googleapiclient.http import MediaFileUpload

        creds_dict = json.loads(creds_json)
        credentials = service_account.Credentials.from_service_account_info(
            creds_dict,
            scopes=["https://www.googleapis.com/auth/drive.file"]
        )
        service = build("drive", "v3", credentials=credentials)

        # Check if file with same name already exists in the folder
        query = f"'{folder_id}' in parents and name = '{pkg_name}' and trashed = false"
        results = service.files().list(q=query, fields="files(id, name)").execute()
        existing_files = results.get("files", [])

        media = MediaFileUpload(pkg_path, mimetype="application/octet-stream", resumable=True)

        if existing_files:
            file_id = existing_files[0]["id"]
            print(f"🔄 Updating existing file in Google Drive (ID: {file_id})...")
            updated = service.files().update(fileId=file_id, media_body=media).execute()
            print(f"✅ Successfully updated Google Drive file! ID: {updated.get('id')}")
        else:
            print(f"⬆️ Uploading new file to Google Drive folder ({folder_id})...")
            file_metadata = {
                "name": pkg_name,
                "parents": [folder_id]
            }
            uploaded = service.files().create(body=file_metadata, media_body=media, fields="id, webViewLink").execute()
            print(f"✅ Successfully uploaded to Google Drive! ID: {uploaded.get('id')}")
            if "webViewLink" in uploaded:
                print(f"🔗 Google Drive Link: {uploaded['webViewLink']}")

    except Exception as e:
        print(f"❌ Google Drive upload error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    upload()
