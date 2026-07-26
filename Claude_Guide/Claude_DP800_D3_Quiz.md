# DP-800 — MIỀN 3: BỘ CÂU HỎI TỰ KIỂM TRA (45 câu)

> Đi kèm [Claude_DP800_D3_AI_Guide.md](./Claude_DP800_D3_AI_Guide.md).
> **Cách dùng:** làm hết phần A, chấm điểm, rồi mới đọc đáp án phần B.
> Mục tiêu: **≥ 36/45 (80%)**.

---

# PHẦN A — CÂU HỎI

## A1. Embedding & vector (câu 1–12)

**1.** Embedding là gì?
- A. Bản nén của văn bản B. **Biểu diễn ngữ nghĩa dưới dạng mảng số nhiều chiều**
- C. Chỉ mục full-text D. Mã băm của văn bản

**2.** Người dùng gõ "tôi muốn trả hàng", tài liệu viết "chính sách hoàn tiền". Cơ chế nào tìm ra?
- A. Full-text search B. `LIKE '%trả hàng%'` C. Vector search D. Regex

**3.** Khai báo `Embedding VECTOR(1536)`. Con số 1536 đến từ đâu?
- A. Số ký tự tối đa B. **Số chiều của model embedding** C. Số dòng D. Kích thước byte

**4.** Sau khi đổi từ `text-embedding-ada-002` sang `text-embedding-3-large`, kết quả tìm kiếm trở nên vô nghĩa. Vì sao?
- A. Vector index hỏng B. Sai metric
- C. **Vector của model cũ không so sánh được với model mới — phải sinh lại toàn bộ**
- D. Số dòng quá lớn

**5.** `VECTOR_DISTANCE('cosine', a, b)` trả về 0 nghĩa là gì?
- A. Không liên quan B. **Hai vector giống hệt nhau** C. Ngược nghĩa D. Lỗi

**6.** Dải giá trị của cosine distance?
- A. 0 đến 1 B. **0 đến 2** C. −1 đến 1 D. Không giới hạn

**7.** Sắp xếp kết quả tìm kiếm vector như thế nào?
- A. `ORDER BY distance DESC` B. **`ORDER BY distance ASC`** C. `ORDER BY similarity ASC` D. Không cần sắp xếp

**8.** Vì sao văn bản thường dùng cosine thay vì euclidean?
- A. Cosine nhanh hơn
- B. **Cosine bỏ qua độ lớn vector (phản ánh độ dài văn bản), chỉ xét hướng (ý nghĩa)**
- C. Euclidean không hỗ trợ D. Cosine chính xác hơn tuyệt đối

**9.** Với vector đã chuẩn hoá (norm = 1), metric nào rẻ nhất mà thứ hạng vẫn đúng?
- A. `cosine` B. `euclidean` C. **`dot`** D. Cả ba như nhau

**10.** `VECTOR_DISTANCE` thuộc loại tìm kiếm nào?
- A. ANN xấp xỉ B. **Exact KNN — quét toàn bảng, chính xác 100%** C. Full-text D. Hash-based

**11.** Điều nào **KHÔNG** làm được với cột kiểu `VECTOR`?
- A. Lưu vào bảng B. Tính khoảng cách C. **So sánh bằng `=` và `GROUP BY` trực tiếp** D. Tạo vector index

**12.** Giới hạn số chiều khi dùng vector index (DiskANN)?
- A. 512 B. 1024 C. **1998** D. Không giới hạn

---

## A2. Vector index, hybrid & lọc (câu 13–22)

**13.** Bảng 50 triệu chunk, cần top-5 trong vài chục ms. Chọn:
- A. `VECTOR_DISTANCE` + `ORDER BY` B. **Vector index + `VECTOR_SEARCH`** C. Full-text D. Columnstore

**14.** Đánh đổi khi dùng vector index (ANN) là gì?
- A. Tốn dung lượng B. **Recall giảm nhẹ (~95–99%) đổi lấy tốc độ** C. Không hỗ trợ cosine D. Không có đánh đổi

**15.** Tạo vector index với `METRIC = 'cosine'` nhưng truy vấn dùng `'euclidean'`. Hậu quả?
- A. Tự chuyển đổi B. **Index bị bỏ qua** C. Báo lỗi cú pháp D. Kết quả vẫn đúng và nhanh

**16.** Sau khi nạp thêm 1 triệu chunk mới, chất lượng tìm kiếm giảm. Nguyên nhân?
- A. Bảng quá lớn B. **Vector index xây offline — dữ liệu mới chưa nằm trong index, cần rebuild**
- C. Sai metric D. Hết bộ nhớ

**17.** Người dùng vừa hỏi bằng ngôn ngữ tự nhiên, vừa tra mã sản phẩm chính xác "SKU-A17X". Chọn:
- A. Chỉ vector B. Chỉ full-text C. **Hybrid search** D. `LIKE`

**18.** Reciprocal Rank Fusion (RRF) hợp nhất kết quả bằng công thức nào?
- A. Trung bình điểm số B. **`Σ 1/(k + rank)`** C. Tích điểm số D. Lấy max

**19.** Ưu điểm của RRF so với cộng điểm số trực tiếp?
- A. Nhanh hơn B. **Chỉ cần thứ hạng nên không phải chuẩn hoá thang đo giữa 2 hệ thống**
- C. Chính xác hơn D. Ít bộ nhớ hơn

**20.** Rủi ro của **post-filter** (tìm top-K trước, lọc sau)?
- A. Chậm hơn B. **Có thể còn ít hơn K kết quả, thậm chí 0** C. Sai metric D. Không dùng được index

**21.** Rủi ro của **pre-filter** khi dùng vector index?
- A. Kết quả sai B. **Có thể làm giảm hiệu quả của ANN** C. Không dùng được cosine D. Tốn RAM

**22.** Đảm bảo người dùng chỉ tìm được tài liệu họ có quyền xem. Cách đúng:
- A. Lọc ở tầng ứng dụng B. **Row-Level Security trên bảng chunk** C. DDM D. Mã hoá cột embedding

---

## A3. Gọi dịch vụ AI từ SQL (câu 23–34)

**23.** `sp_invoke_external_rest_endpoint` có trên nền tảng nào?
- A. Mọi phiên bản SQL Server B. **Azure SQL DB / MI / SQL Server 2025** C. Chỉ Azure SQL DB D. SQL Server 2019+

**24.** Giao thức được chấp nhận?
- A. HTTP và HTTPS B. **Chỉ HTTPS** C. HTTP, HTTPS, FTP D. Chỉ HTTP nội bộ

**25.** Giới hạn của `@timeout`?
- A. 1–60 giây B. 1–120 giây C. **1–230 giây** D. Không giới hạn

**26.** JSON trong `@response` có mấy nhánh gốc và là gì?
- A. 2: `data`, `error` B. **3: `$.response`, `$.result`, `$.error`** C. 1: `$.body` D. 4 nhánh

**27.** Lấy mảng embedding từ phản hồi, dùng hàm nào?
- A. `JSON_VALUE` B. **`JSON_QUERY`** C. `OPENJSON` (bắt buộc) D. `CAST`

**28.** Tên của database scoped credential phải là gì?
- A. Tên tuỳ ý B. **Trùng URL gốc của endpoint** C. Tên model D. Tên database

**29.** Cách xác thực an toàn nhất tới Azure OpenAI?
- A. Khoá API trong `@headers` B. Credential chứa khoá C. **Managed Identity** D. Chuỗi kết nối

**30.** Mã HTTP nào **không nên** retry?
- A. 429 B. 503 C. **401 / 403 / 404** D. 408

**31.** Vì sao **không** gọi `sp_invoke_external_rest_endpoint` trong trigger?
- A. Không được phép về cú pháp
- B. **Lời gọi đồng bộ, giữ khoá suốt thời gian chờ mạng (tới 230s)**
- C. Trigger không có quyền D. Kết quả không dùng được

**32.** `CREATE EXTERNAL MODEL` với `MODEL_TYPE = EMBEDDINGS` dùng để làm gì?
- A. Sinh câu trả lời B. **Khai báo model sinh embedding, dùng qua `AI_GENERATE_EMBEDDINGS`**
- C. Huấn luyện model D. Lưu model ONNX

**33.** Muốn gọi một API dịch thuật bất kỳ (không phải AI) từ SQL. Dùng:
- A. `CREATE EXTERNAL MODEL` B. `PREDICT` C. **`sp_invoke_external_rest_endpoint`** D. `OPENROWSET`

**34.** Cần chấm điểm rủi ro cho 10 triệu khách hàng bằng model ML đã huấn luyện, độ trễ thấp, không phụ thuộc mạng. Chọn:
- A. External model + REST B. **`PREDICT` với model ONNX** C. `AI_GENERATE_CHAT` D. Azure AI Search

---

## A4. RAG (câu 35–45)

**35.** Thứ tự đúng của pha nạp trong RAG?
- A. Embedding → chunking → lưu → index B. **Chunking → embedding → lưu → index**
- C. Lưu → chunking → embedding D. Index → chunking → embedding

**36.** Câu hỏi của người dùng phải được embed bằng:
- A. Model nào cũng được B. Model mạnh nhất
- C. **Đúng model đã dùng để embed tài liệu** D. Không cần embed

**37.** Kích thước chunk khuyến nghị?
- A. 10–50 token B. **200–800 token** C. 5000+ token D. Cả tài liệu là 1 chunk

**38.** Vì sao cần overlap giữa các chunk?
- A. Tăng tốc tìm kiếm B. **Tránh cắt đứt câu/ý ở ranh giới chunk** C. Giảm chi phí D. Bắt buộc về kỹ thuật

**39.** Tỷ lệ overlap khuyến nghị?
- A. 0% B. **10–20%** C. 50% D. 80%

**40.** Thành phần nào của prompt RAG giảm hallucination **hiệu quả nhất**?
- A. Vai trò của trợ lý B. **Lối thoát: "nếu không có thông tin thì nói không biết"**
- C. Định dạng đầu ra D. Độ dài prompt

**41.** `temperature = 0` khi gọi LLM trong RAG có tác dụng gì?
- A. Nhanh hơn B. Rẻ hơn C. **Câu trả lời ổn định, ít bịa** D. Trả lời dài hơn

**42.** Chỉ số nào đo chất lượng **truy xuất** (retrieval)?
- A. Groundedness B. **Recall@K** C. Answer relevance D. Perplexity

**43.** Recall@3 thấp. Vấn đề nằm ở đâu và sửa gì trước?
- A. Ở LLM — đổi model chat
- B. **Ở truy xuất — chỉnh chunking, tăng top-K, thêm hybrid/reranking**
- C. Ở prompt — viết lại system prompt D. Ở hạ tầng — tăng RAM

**44.** Recall tốt nhưng câu trả lời vẫn sai. Sửa ở đâu?
- A. Chunking B. Vector index C. **Ở khâu sinh: siết prompt, giảm temperature, buộc trích dẫn** D. Metric

**45.** Cách giảm chi phí embedding hiệu quả nhất khi tài liệu ít thay đổi?
- A. Giảm số chiều B. Dùng model rẻ hơn
- C. **So checksum nội dung, chỉ sinh lại embedding cho chunk đã thay đổi** D. Giảm top-K

---
---

# PHẦN B — ĐÁP ÁN & GIẢI THÍCH

| # | Đ.A | Giải thích ngắn |
|---|---|---|
| 1 | **B** | Mảng số thực nhiều chiều; hai nội dung gần nghĩa thì hai vector gần nhau. |
| 2 | **C** | Không trùng từ khoá nào ⇒ chỉ vector search (ngữ nghĩa) tìm được. |
| 3 | **B** | Số chiều do model quyết định; sai chiều ⇒ lỗi khi ghi. |
| 4 | **C** | Không gian vector của hai model khác nhau hoàn toàn, không so sánh chéo được. |
| 5 | **B** | Distance 0 = giống hệt. 1 = trực giao. 2 = ngược hẳn. |
| 6 | **B** | cosine similarity ∈ [−1,1] ⇒ distance = 1 − sim ∈ [0,2]. |
| 7 | **B** | Đây là **khoảng cách**, nhỏ = giống ⇒ ASC + TOP. Chọn DESC là bẫy phổ biến nhất. |
| 8 | **B** | Độ dài vector phản ánh độ dài văn bản chứ không phản ánh ý nghĩa. |
| 9 | **C** | Chuẩn hoá rồi thì cosine, euclidean, dot cho cùng thứ hạng; dot rẻ nhất (không khai căn). |
| 10 | **B** | Exact KNN — chính xác nhưng chậm tuyến tính theo số dòng. |
| 11 | **C** | Không so sánh `=`, không GROUP BY/ORDER BY trực tiếp, không làm khoá B-Tree. |
| 12 | **C** | 1998 chiều. |
| 13 | **B** | Bảng lớn + yêu cầu độ trễ thấp ⇒ ANN. |
| 14 | **B** | ANN đánh đổi recall lấy tốc độ — đó là định nghĩa của "xấp xỉ". |
| 15 | **B** | Metric không khớp ⇒ optimizer không dùng được index, quay về quét toàn bảng. |
| 16 | **B** | Index xây trên ảnh chụp; dữ liệu mới nằm ngoài ⇒ rebuild định kỳ. |
| 17 | **C** | Hybrid = vector (ngữ nghĩa) + full-text (chính xác), hợp nhất bằng RRF. |
| 18 | **B** | `score = Σ 1/(k + rank)`, k thường = 60. |
| 19 | **B** | Chỉ dùng thứ hạng nên miễn nhiễm với việc hai hệ thống có thang điểm khác nhau. |
| 20 | **B** | Lọc sau có thể loại hết kết quả ⇒ thực hành tốt là lấy top-N lớn hơn rồi cắt. |
| 21 | **B** | Vị từ lọc làm ANN mất lợi thế cấu trúc index. |
| 22 | **B** | RLS áp ở tầng engine, người dùng truy vấn trực tiếp cũng bị lọc. Lọc ở ứng dụng là sai. |
| 23 | **B** | Không có trên SQL Server ≤ 2022. |
| 24 | **B** | HTTP bị từ chối thẳng. |
| 25 | **C** | 1–230 giây, mặc định 30. |
| 26 | **B** | `$.response` (status/headers), `$.result` (body), `$.error` (khi lỗi). |
| 27 | **B** | Embedding là **mảng** ⇒ JSON_QUERY. JSON_VALUE lên mảng trả NULL. |
| 28 | **B** | Tên credential phải trùng URL gốc — chi tiết sai nhiều nhất khi triển khai. |
| 29 | **C** | Managed Identity không có khoá để lộ, tự xoay vòng. |
| 30 | **C** | 401/403 (xác thực/quyền/firewall), 404 (sai URL) — retry vô ích. 408/429/5xx thì retry. |
| 31 | **B** | Đồng bộ, giữ khoá suốt thời gian chờ mạng ⇒ chặn cả hệ thống. |
| 32 | **B** | Khai báo một lần, dùng qua `AI_GENERATE_EMBEDDINGS(... USE MODEL ...)`. |
| 33 | **C** | REST endpoint gọi được API bất kỳ; external model chỉ cho các API_FORMAT đã biết. |
| 34 | **B** | `PREDICT` chạy ONNX trong engine — không gọi mạng, hợp scoring hàng loạt. |
| 35 | **B** | Chunk trước rồi mới embed từng chunk. |
| 36 | **C** | Khác model ⇒ khác không gian vector ⇒ kết quả vô nghĩa. |
| 37 | **B** | Nhỏ quá mất ngữ cảnh, lớn quá pha loãng ngữ nghĩa và tốn token. |
| 38 | **B** | Nếu câu trả lời vắt qua ranh giới, ít nhất một chunk vẫn chứa trọn ý. |
| 39 | **B** | 10–20% kích thước chunk. |
| 40 | **B** | Cho mô hình một lối thoát hợp lệ là cách giảm bịa hiệu quả nhất; kết hợp buộc trích dẫn. |
| 41 | **C** | Temperature thấp = ít ngẫu nhiên = bám ngữ cảnh hơn. |
| 42 | **B** | Recall@K/Precision@K/MRR đo truy xuất; groundedness và answer relevance đo sinh. |
| 43 | **B** | Recall thấp là lỗi ở khâu tìm, không phải khâu trả lời. |
| 44 | **C** | Đã lấy đúng tài liệu mà vẫn sai ⇒ vấn đề ở khâu sinh. |
| 45 | **C** | Không sinh lại thứ không đổi — tiết kiệm lớn nhất và dễ triển khai nhất. |

---

## THANG ĐIỂM

| Điểm | Nhận định |
|---|---|
| 41–45 | Sẵn sàng thi miền 3. |
| 36–40 | Đạt. Đọc lại mục sai, chạy lại lab tương ứng. |
| 30–35 | Chưa an toàn. Ôn lại guide + chạy lại Lab 01 và Lab 03. |
| < 30 | Học lại theo lộ trình 4 ngày ở mục 9 của guide. |

## BẢN ĐỒ CÂU HỎI → TÀI LIỆU ÔN

| Câu | Mục trong Guide | Lab |
|---|---|---|
| 1–12 | 1. Embedding, 2. `VECTOR_DISTANCE` | [Lab 01](./Claude_DP800_D3_Lab01_Vectors_Embeddings.sql) §1–5 |
| 13–22 | 3. Vector index, 1.1 Hybrid | [Lab 01](./Claude_DP800_D3_Lab01_Vectors_Embeddings.sql) §6–9 |
| 23–34 | 4. Sinh embedding trong SQL, 6. Khả năng khác | [Lab 02](./Claude_DP800_D3_Lab02_ExternalEndpoints_Models.sql) |
| 35–45 | 5. Kiến trúc RAG | [Lab 03](./Claude_DP800_D3_Lab03_RAG_Pipeline.sql) |
