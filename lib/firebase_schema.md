# Firestore Data Schema

## users (Collection)
- **Document ID**: 사용자 UID
- **Fields**:
  - `user_name`: string (사용자 이름)
  - `user_id`: string (사용자 ID)
  - `user_password`: string (사용자 비밀번호)
  - `user_group_id`: string (소속 그룹 ID, 없으면 빈 문자열)
  - `user_email`: string (이메일)
  - `displayName`: string (표시 이름, Google 로그인 시)
  **->`display_name`으로 변경**
  - `email`: string (이메일, Google 로그인 시)
  - `createdAt`: Timestamp (생성일)
  **->`created_at`으로 변경**

---

## groups (Collection)
- **Document ID**: 그룹 ID
- **Fields**:
  - `group_name`: string (그룹 이름)
  - `group_users`: array of string (그룹에 속한 사용자 UID 목록)
  - `group_manager`: string (그룹 관리자 UID)
  - `created_at`: string (ISO8601, 그룹 생성일)
  

---

## tasks (Collection)
- **Document ID**: 자동 생성
- **Fields**:
  - `task_name`: string (업무 이름)
  - `task_script`: string (업무 설명)
  - `finished_at`: Timestamp (마감 기한)
  - `created_at`: Timestamp (생성일)
  - `assigned_users`: array of string (할당된 사용자 UID 목록)
  - `managed_by`: string (업무 관리자 UID, 개인 업무는 빈 문자열)
  - `state`: array of int (각 사용자별 업무 상태, 0: 시작 전, 1: 진행중, 2: 완료)
  - `alert`: array of bool (각 사용자별 알림 여부)

---

## posts (Collection)
- **Document ID**: 자동 생성
- **Fields**:
  - `title`: string (게시물 제목)
  - `title_arr`: array of string (검색용 제목 분해 배열)
  - `relatedWork`: string (관련 업무명)
  **->`related_work`로 변경**
  - `related_task_id`: string (관련 업무 ID)
  - `description`: string (설명)
  - `imageUrl`: array of string (이미지 파일 URL 목록)
  **->`image_url`로 변경**
  - `fileUrl`: array of string (첨부 파일 URL 목록)
  **->`file_url`로 변경**
  - `createdAt`: Timestamp (생성일)
  **->`created_at`로 변경**
  - `group_id`: string (소속 그룹 ID)
  - `made_by`: string (작성자 UID)

---

## comments (Collection)
- **Document ID**: 자동 생성
- **Fields**:
  - `post_id`: string (댓글이 달린 게시물 ID)
  - `title`: string (댓글 내용)
  - `title_arr`: array of string (검색용 댓글 분해 배열, 선택적)
  - `createdAt`: Timestamp (댓글 생성일)
  **-> `created_at`로 변경**
  - `made_by`: string (댓글 작성자 UID)
  - `user_name`: string (댓글 작성자 이름)
  - `file_url`: string (첨부 파일 URL, 없으면 빈 문자열)

---

## 기타
- 각 컬렉션의 문서에는 필요에 따라 추가 필드가 있을 수 있습니다.
- Timestamp는 Firestore의 날짜/시간 타입입니다. 