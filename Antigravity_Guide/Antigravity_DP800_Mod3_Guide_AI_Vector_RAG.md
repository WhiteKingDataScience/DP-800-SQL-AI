# CẨM NANG CHUYÊN SÂU ÔN THI DP-800: IMPLEMENT AI CAPABILITIES IN DATABASE SOLUTIONS (25–30%)
> **Tác giả:** Expert Database Solutions Architect (10+ năm kinh nghiệm Microsoft SQL Server & Azure Data Platform)  
> **Phân loại:** MODULE 3 — LÝ THUYẾT & MẸO THI  
> **Kỳ thi:** DP-800: Developing AI-Enabled Database Solutions (Cập nhật mới nhất tháng 03/2026)  
> **File thực hành SQL đính kèm:**  
> - 📄 [Antigravity_DP800_Mod3_Lab01_AI_Vector_Search_RAG.sql](file:///d:/SQL/DP-800%20Microsoft%20SQL%20Server%20AI%20Developer/Antigravity_DP800_Mod3_Lab01_AI_Vector_Search_RAG.sql)

---

## 📌 TỔNG QUAN VỀ MIỀN KỸ NĂNG AI (25–30%)

Miền kiến thức **"Implement AI capabilities in database solutions"** là trọng tâm đột phá của kỳ thi DP-800. Đây là miền kiểm tra năng lực biến SQL Server / Azure SQL thành một **AI-Native Database Engine** có khả năng:
1. **Quản lý Models & Embeddings:** Chunking văn bản, gọi Azure OpenAI/Foundry tạo Embedding, duy trì đồng bộ Vector embedding bằng Change Tracking / Triggers / Event Streaming.
2. **Tìm kiếm thông minh (Intelligent Search):** Kết hợp Full-Text Search (Từ khóa) + Vector Search (Ngữ nghĩa) qua thuật toán **Reciprocal Rank Fusion (RRF)**.
3. **Retrieval-Augmented Generation (RAG):** Đóng gói ngữ cảnh cơ sở dữ liệu thành JSON và gọi trực tiếp LLM từ T-SQL qua **`sp_invoke_external_rest_endpoint`**.

---

## 🧠 CHUYÊN ĐỀ 1: DESIGN AND IMPLEMENT MODELS AND EMBEDDINGS

### 1. Chunking & Chuẩn bị dữ liệu cho AI
* **Khái niệm Chunking:** Chia nhỏ văn bản dài thành các đoạn văn ngắn (Chunks) vừa vặn với Context Window của Model (VD: 512 hoặc 1000 tokens) kèm độ chồng lấp (Overlap ~10-20%) để tránh mất ngữ cảnh ở ranh giới đoạn.
* **Lựa chọn cột làm Embedding:** Chọn các cột văn bản chứa giá trị ngữ nghĩa phong phú (Title, Description, Article Content). Tránh đưa các cột ID, Timestamp, hoặc mã số vào embedding.

---

### 2. Các phương pháp duy trì Embeddings (Embedding Maintenance Pipeline)

| Phương pháp | Đặc điểm kiến trúc | Đánh giá cho đề thi DP-800 |
| :--- | :--- | :--- |
| **Table Triggers (`AFTER INSERT/UPDATE`)** | Tự động kích hoạt code cập nhật embedding ngay khi dòng dữ liệu thay đổi. | Đơn giản nhưng gây chậm giao dịch chính (Synchronous overhead). Không khuyên dùng cho tải lớn. |
| **Change Tracking (CT) + Azure Functions** | Azure Function định kỳ đọc bảng `CHANGETABLE()` và gọi API tạo Embedding bất đồng bộ. | **Khuyên dùng nhất (Best Practice)** vì hoạt động bất đồng bộ (Asynchronous), không ảnh hưởng OLTP. |
| **Change Event Streaming (CES)** | Đẩy sự kiện qua Azure Event Grid tới Event Hubs / Logic Apps. | Thích hợp cho kiến trúc Event-Driven Enterprise quy mô lớn. |
| **Microsoft Foundry Integration** | Tích hợp trực tiếp các mô hình AI từ Microsoft AI Foundry vào Data Pipeline. | Chuẩn hóa quy trình AI Lifecycle quản lý Model Endpoints. |

---

## 🔍 CHUYÊN ĐỀ 2: DESIGN AND IMPLEMENT INTELLIGENT SEARCH

### 1. Kiểu dữ liệu Vector & Các hàm Vector Native trong SQL
* **Khái niệm:** Cột `VECTOR(1536)` lưu trữ chuỗi số thực đại diện cho vị trí ngữ nghĩa của văn bản trong không gian đa chiều.
* **Các hàm Vector quan trọng:**
  * `VECTOR_DISTANCE(metric, v1, v2)`: Tính khoảng cách giữa 2 vector.
    * `'cosine'`: Đo góc giữa 2 vector (Phù hợp nhất cho Text Search).
    * `'euclidean'`: Khoảng cách hình học L2 norm.
    * `'dot'`: Tích vô hướng (Dùng khi các vector đã được chuẩn hóa).
  * `VECTOR_NORMALIZE(v)`: Đưa độ dài vector về 1 (L2 Normalization).
  * `VECTORPROPERTY(v, 'dimensions')`: Lấy số chiều của vector.

---

### 2. So sánh Vector Search: ANN vs ENN

```
                            ┌──► ENN (Exact Nearest Neighbor) ──► Scan 100% dữ liệu (Exact, Chậm)
Vector Search Algorithms ───┤
                            └──► ANN (Approximate Nearest Neighbor) ──► Dùng HNSW / DiskANN Index (Nhanh, Siêu nhẹ)
```

* **Exact Nearest Neighbor (ENN):** Duyệt qua toàn bộ danh sách vector trong database. Độ chính xác 100% nhưng thời gian phản hồi tăng tuyến tính theo số lượng dòng ($O(N)$).
* **Approximate Nearest Neighbor (ANN):** Sử dụng Vector Index cấu trúc đồ thị **HNSW (Hierarchical Navigable Small World)** hoặc **DiskANN**. Tìm kiếm với độ phức tạp $O(\log N)$, phản hồi trong vài millisecond trên tập dữ liệu hàng triệu dòng.

---

### 3. Hybrid Search & Reciprocal Rank Fusion (RRF)
* **Tại sao cần Hybrid Search?**
  * Full-Text Search giỏi tìm từ khóa chính xác (VD: Mã sản phẩm "SKU-9921", Tên riêng).
  * Vector Search giỏi tìm ý nghĩa / khái niệm tương đương (VD: "Điện thoại pin trâu" ➔ "Smartphone dung lượng battery 5000mAh").
  * **Hybrid Search = Full-Text Search + Vector Search.**
* **Thuật toán Reciprocal Rank Fusion (RRF):**
  * Công thức tính điểm tổng hợp:
    $$\text{RRF\_Score} = \sum_{m \in M} \frac{1}{k + r_m(d)}$$
  * Trong đó $k$ thường chọn là $60$, $r_m(d)$ là thứ hạng của tài liệu $d$ trong hệ thống tìm kiếm $m$.

---

## 🤖 CHUYÊN ĐỀ 3: DESIGN AND IMPLEMENT RAG (RETRIEVAL-AUGMENTED GENERATED)

### 1. Kiến trúc RAG trong SQL Engine

```
[User Question] ──► Generate Query Vector ──► Vector Search trong SQL Database ──► Extract Top K Chunks
                                                                                       │
[LLM Final Answer] ◄── sp_invoke_external_rest_endpoint ◄── Build JSON RAG Prompt ─────┘
```

---

### 2. Sử dụng `sp_invoke_external_rest_endpoint`
* **Cú pháp gọi REST Endpoint trực tiếp từ T-SQL:**
  ```sql
  DECLARE @response NVARCHAR(MAX);
  
  EXEC sys.sp_invoke_external_rest_endpoint
      @url = N'https://<your-openai-instance>.openai.azure.com/openai/deployments/gpt-4o/chat/completions?api-version=2024-02-01',
      @method = N'POST',
      @headers = N'{"Content-Type":"application/json", "api-key":"<API_KEY>"}',
      @payload = @PayloadJSON,
      @timeout = 30,
      @result = @response OUTPUT;
  ```
* **Bóc tách kết quả từ LLM:** Sử dụng `JSON_VALUE(@response, '$.result.choices[0].message.content')` để lấy câu trả lời dạng text hoặc JSON từ mô hình ngôn ngữ lớn.

---

## 🎯 TỔNG KẾT BÀI THI DP-800 CHUYÊN ĐỀ AI

1. **Nhớ công thức RRF:** Luôn kết hợp `FULL OUTER JOIN` giữa kết quả Vector Search và Full-Text Search với trọng số `1.0 / (60 + Rank)`.
2. **Chọn cách cập nhật Vector Embedding:** Nếu câu hỏi yêu cầu **không làm giảm hiệu năng OLTP**, câu trả lời đúng luôn là: **Change Tracking + Azure Functions (Asynchronous)**.
3. **Cách gọi LLM từ SQL Server:** Dùng duy nhất Stored Procedure **`sys.sp_invoke_external_rest_endpoint`**.

---
*Chúc bạn thi tốt và đạt chứng chỉ DP-800 Microsoft Certified: AI-Enabled Database Solutions!*
