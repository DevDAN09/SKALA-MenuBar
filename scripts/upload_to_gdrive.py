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

    # Sanitize folder_id in case the user passed full URL or query parameters
    folder_id = folder_id.strip()
    if "folders/" in folder_id:
        folder_id = folder_id.split("folders/")[1].split("?")[0].split("/")[0]
    elif "/" in folder_id:
        folder_id = folder_id.rstrip("/").split("/")[-1].split("?")[0]
    folder_id = folder_id.split("?")[0].strip()

    pkg_files = glob.glob("dist/*.pkg")
    if not pkg_files:
        print("❌ No .pkg file found in dist/")
        sys.exit(1)

    pkg_path = sorted(pkg_files, key=os.path.getmtime, reverse=True)[0]
    pkg_name = os.path.basename(pkg_path)
    file_size_mb = os.path.getsize(pkg_path) / (1024 * 1024)

    print(f"📦 Target PKG: {pkg_name} ({file_size_mb:.2f} MB)")
    print(f"📁 Target Folder ID: {folder_id}")

    try:
        from google.oauth2 import service_account
        from googleapiclient.discovery import build
        from googleapiclient.http import MediaFileUpload

        creds_dict = json.loads(creds_json)
        credentials = service_account.Credentials.from_service_account_info(
            creds_dict,
            scopes=["https://www.googleapis.com/auth/drive"]
        )
        service = build("drive", "v3", credentials=credentials)

        # 1. Verify authentication identity
        try:
            about = service.about().get(fields="user").execute()
            user_info = about.get("user", {})
            print(f"👤 Service Account: {user_info.get('emailAddress', 'unknown')}")
        except Exception as auth_err:
            print(f"⚠️ Could not fetch user info: {auth_err}")

        # 2. Check all visible folders for this service account
        try:
            visible_res = service.files().list(
                q="mimeType = 'application/vnd.google-apps.folder' and trashed = false",
                fields="files(id, name)",
                supportsAllDrives=True,
                includeItemsFromAllDrives=True
            ).execute()
            visible_folders = visible_res.get("files", [])
            print(f"📂 Service account can see {len(visible_folders)} folder(s):")
            for f in visible_folders:
                print(f"   - {f.get('name')} (ID: {f.get('id')})")
        except Exception as list_err:
            print(f"⚠️ Could not list visible folders: {list_err}")

        # 3. Check folder access and capabilities
        try:
            folder = service.files().get(
                fileId=folder_id,
                fields="id, name, capabilities",
                supportsAllDrives=True
            ).execute()
            print(f"📁 Folder access verified: '{folder.get('name')}' (ID: {folder.get('id')})")
            can_add = folder.get("capabilities", {}).get("canAddChildren", False)
            print(f"🔑 Can write to folder: {can_add}")
            if not can_add:
                print("❌ Service account does not have 'Editor/Writer' permissions on this folder!")
                sys.exit(1)
        except Exception as folder_err:
            print(f"❌ Folder access check failed: {folder_err}")
            client_email = creds_dict.get("client_email", "unknown")
            print(f"\n💡 [확인 사항]")
            print(f"1. 구글 드라이브 폴더({folder_id})에 아래 이메일이 '편집자(Editor)'로 공유되어 있는지 확인:")
            print(f"   👉 {client_email}")
            print(f"2. 만약 회사/조직 계정(Google Workspace)인 경우, '조직 외부 사용자와 공유'가 허용되어 있는지 확인해 주세요.")
            sys.exit(1)

        # Check if file with same name already exists in the folder (supports personal and shared drives)
        query = f"'{folder_id}' in parents and name = '{pkg_name}' and trashed = false"
        results = service.files().list(
            q=query,
            fields="files(id, name)",
            supportsAllDrives=True,
            includeItemsFromAllDrives=True
        ).execute()
        existing_files = results.get("files", [])

        media = MediaFileUpload(pkg_path, mimetype="application/octet-stream", resumable=True)

        if existing_files:
            file_id = existing_files[0]["id"]
            print(f"🔄 Updating existing file in Google Drive (ID: {file_id})...")
            updated = service.files().update(
                fileId=file_id,
                media_body=media,
                supportsAllDrives=True
            ).execute()
            print(f"✅ Successfully updated Google Drive file! ID: {updated.get('id')}")
        else:
            print(f"⬆️ Uploading new file to Google Drive folder ({folder_id})...")
            file_metadata = {
                "name": pkg_name,
                "parents": [folder_id]
            }
            uploaded = service.files().create(
                body=file_metadata,
                media_body=media,
                fields="id, webViewLink",
                supportsAllDrives=True
            ).execute()
            print(f"✅ Successfully uploaded to Google Drive! ID: {uploaded.get('id')}")
            if "webViewLink" in uploaded:
                print(f"🔗 Google Drive Link: {uploaded['webViewLink']}")

    except Exception as e:
        print(f"❌ Google Drive upload error: {e}")
        if "File not found" in str(e) or "404" in str(e):
            client_email = "알 수 없음"
            try:
                client_email = json.loads(creds_json).get("client_email", "알 수 없음")
            except Exception:
                pass
            print(f"\n💡 [해결 가이드] 구글 드라이브 폴더를 찾을 수 없습니다 (404 Not Found).")
            print(f"1. 대상 구글 드라이브 폴더 우클릭 ➡️ [공유] ➡️ 아래 서비스 계정 이메일을 '편집자'로 추가했는지 꼭 확인해 주세요:")
            print(f"   👉 {client_email}")
            print(f"2. GDRIVE_FOLDER_ID 값({folder_id})이 올바른지 확인해 주세요.")
        sys.exit(1)

if __name__ == "__main__":
    upload()
