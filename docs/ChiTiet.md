## Chi tiết phương pháp

Bài toán được tiếp cận theo hướng **segmentation ảnh y tế phục vụ đếm tế bào**. Mục tiêu chính là tách vùng tế bào ra khỏi nền ảnh, xử lý các trường hợp tế bào bị dính cụm hoặc chồng lấn, sau đó đếm số lượng tế bào có trong từng ảnh.

Trong nghiên cứu này, hai hướng tiếp cận được xây dựng và so sánh:

- **Nhánh xử lý ảnh truyền thống (Traditional Computer Vision)**
- **Nhánh Machine Learning không giám sát**

Hai nhánh đều hướng đến cùng một mục tiêu: tạo ra mask phân đoạn tế bào và sử dụng mask đó để ước lượng số lượng tế bào trong ảnh.

### 1. Nhánh xử lý ảnh truyền thống (Traditional Computer Vision)

Nhánh xử lý ảnh truyền thống sử dụng các kỹ thuật xử lý ảnh cổ điển để cải thiện chất lượng ảnh, tách vùng tế bào và đếm số lượng đối tượng. Ưu điểm của hướng tiếp cận này là dễ triển khai, không yêu cầu dữ liệu huấn luyện lớn và có khả năng giải thích rõ ràng qua từng bước xử lý.

Quy trình tổng quát gồm bốn bước chính:

1. Tiền xử lý ảnh.
2. Tách vùng tế bào khỏi nền.
3. Tách các cụm tế bào dính nhau.
4. Đếm số lượng tế bào.

#### 1.1. Tiền xử lý ảnh

Ảnh y tế thường gặp các vấn đề như nhiễu, độ tương phản thấp, biên tế bào không rõ hoặc nền ảnh không đồng đều. Vì vậy, bước tiền xử lý được áp dụng để làm nổi bật vùng tế bào và giúp các bước phân đoạn phía sau hoạt động ổn định hơn.

Các kỹ thuật được sử dụng gồm:

##### Gaussian Blur

Gaussian Blur được dùng để làm mượt ảnh và giảm các nhiễu nhỏ. Việc làm mượt giúp hạn chế hiện tượng các điểm nhiễu bị nhận nhầm thành tế bào trong bước thresholding.

**Đặc trưng:**

- Giảm nhiễu cường độ cao.
- Làm ảnh mượt hơn trước khi phân đoạn.
- Giúp kết quả threshold ổn định hơn.
- Có thể làm mờ biên tế bào nếu kích thước kernel quá lớn.

##### CLAHE

CLAHE được sử dụng để tăng cường độ tương phản cục bộ trong ảnh. Phương pháp này phù hợp với ảnh y tế vì nhiều ảnh có độ sáng không đồng đều giữa các vùng.

**Đặc trưng:**

- Tăng độ tương phản cục bộ.
- Làm rõ vùng tế bào so với nền.
- Hạn chế khuếch đại nhiễu quá mức so với histogram equalization thông thường.
- Phù hợp với ảnh có nền sáng tối không đồng nhất.

##### Median Filter

Median Filter được dùng để loại bỏ nhiễu dạng muối tiêu trong ảnh. Khác với lọc trung bình, Median Filter có khả năng giữ biên đối tượng tốt hơn.

**Đặc trưng:**

- Hiệu quả với nhiễu muối tiêu.
- Giữ biên tế bào tương đối tốt.
- Phù hợp khi ảnh có nhiều điểm nhiễu rời rạc.
- Ít làm nhòe biên hơn so với một số bộ lọc làm mượt tuyến tính.

#### 1.2. Tách nền và đối tượng bằng Thresholding

Sau khi tiền xử lý, ảnh được chuyển sang dạng nhị phân để phân biệt giữa vùng tế bào và vùng nền. Đây là bước biến bài toán segmentation thành bài toán phân loại pixel đơn giản: mỗi pixel được gán vào một trong hai nhóm là **tế bào** hoặc **nền**.

Hai phương pháp thresholding được sử dụng gồm:

##### Otsu Thresholding

Otsu Thresholding tự động tìm ngưỡng phân tách tối ưu dựa trên phân bố mức xám của ảnh. Phương pháp này phù hợp khi ảnh có sự khác biệt rõ ràng giữa vùng tế bào và vùng nền.

**Đặc trưng:**

- Tự động chọn ngưỡng.
- Không cần đặt ngưỡng thủ công.
- Hoạt động tốt khi histogram có hai nhóm mức xám tương đối rõ.
- Kém hiệu quả nếu nền ảnh không đồng đều hoặc độ tương phản giữa tế bào và nền thấp.

##### Adaptive Thresholding

Adaptive Thresholding tính ngưỡng cục bộ cho từng vùng nhỏ trong ảnh thay vì dùng một ngưỡng chung cho toàn ảnh. Phương pháp này phù hợp với ảnh có ánh sáng không đồng đều hoặc nền thay đổi theo không gian.

**Đặc trưng:**

- Thích hợp với ảnh có nền không đồng nhất.
- Có khả năng xử lý các vùng sáng tối khác nhau trong cùng một ảnh.
- Nhạy với kích thước vùng lân cận và tham số hiệu chỉnh ngưỡng.
- Có thể tạo nhiễu nếu tham số không phù hợp.

#### 1.3. Tách cụm tế bào bằng Distance Transform và Watershed

Trong ảnh tế bào, nhiều tế bào có thể dính vào nhau tạo thành một cụm lớn. Nếu chỉ dùng Connected Components hoặc Contours trực tiếp, các cụm này có thể bị đếm thành một tế bào duy nhất. Vì vậy, cần có bước tách cụm để phân tách các tế bào tiếp xúc nhau.

##### Distance Transform

Distance Transform tính khoảng cách từ mỗi pixel trong vùng tế bào đến nền gần nhất. Các vùng nằm gần trung tâm tế bào thường có giá trị khoảng cách lớn, từ đó có thể dùng để xác định marker ban đầu cho từng tế bào.

**Đặc trưng:**

- Làm nổi bật vùng trung tâm của tế bào.
- Hỗ trợ xác định marker cho watershed.
- Có ích khi các tế bào dính nhau nhưng vẫn còn cấu trúc trung tâm riêng biệt.
- Phụ thuộc vào chất lượng mask nhị phân ban đầu.

##### Watershed

Watershed sử dụng các marker đã xác định để chia các cụm tế bào dính nhau thành những vùng riêng biệt. Có thể xem phương pháp này như quá trình “ngập nước” từ các marker, trong đó đường phân chia được tạo ra tại ranh giới giữa các vùng lan truyền.

**Đặc trưng:**

- Tách được các tế bào dính cụm.
- Cải thiện độ chính xác khi đếm tế bào.
- Hiệu quả phụ thuộc nhiều vào marker đầu vào.
- Có thể bị over-segmentation nếu marker quá nhiều hoặc mask còn nhiễu.

#### 1.4. Đếm tế bào bằng Connected Components hoặc Contours

Sau khi có mask segmentation cuối cùng, số lượng tế bào được xác định bằng cách đếm các vùng liên thông hoặc đường bao đối tượng.

##### Connected Components

Connected Components gán nhãn cho từng vùng liên thông trong ảnh nhị phân. Mỗi vùng hợp lệ được xem là một đối tượng tế bào.

**Đặc trưng:**

- Dễ triển khai.
- Phù hợp với mask nhị phân rõ ràng.
- Cho phép lọc đối tượng theo diện tích, chiều rộng, chiều cao hoặc tỉ lệ hình dạng.
- Có thể đếm sai nếu nhiều tế bào dính nhau chưa được tách tốt.

##### Contours

Contours phát hiện đường biên của từng đối tượng trong ảnh. Sau đó, số lượng contour hợp lệ được dùng để ước lượng số lượng tế bào.

**Đặc trưng:**

- Tập trung vào hình dạng và đường biên đối tượng.
- Có thể kết hợp với các tiêu chí lọc như diện tích, chu vi hoặc độ tròn.
- Phù hợp khi biên tế bào rõ.
- Nhạy với nhiễu biên và các vùng bị đứt gãy.

Các vùng quá nhỏ thường được loại bỏ để tránh đếm nhầm nhiễu thành tế bào.

### 2. Nhánh Machine Learning

Nhánh Machine Learning tiếp cận bài toán bằng cách biểu diễn mỗi pixel hoặc vùng ảnh dưới dạng vector đặc trưng, sau đó sử dụng thuật toán phân cụm để tách tế bào khỏi nền. Trong bài toán này, K-Means được sử dụng vì không yêu cầu nhãn pixel chi tiết.

Quy trình tổng quát gồm bốn bước chính:

1. Trích xuất đặc trưng pixel.
2. Phân cụm bằng K-Means.
3. Hậu xử lý mask.
4. So sánh kết quả đếm với nhãn thật.

#### 2.1. Biểu diễn pixel bằng đặc trưng

Mỗi pixel trong ảnh được biểu diễn thành một vector đặc trưng. Thay vì chỉ sử dụng giá trị pixel đơn lẻ, phương pháp có thể kết hợp thêm thông tin từ vùng lân cận để mô tả ngữ cảnh xung quanh pixel.

Các đặc trưng có thể bao gồm:

- Giá trị cường độ sáng của pixel.
- Giá trị mức xám sau tiền xử lý.
- Thông tin màu sắc nếu ảnh có nhiều kênh.
- Đặc trưng lân cận như giá trị trung bình, độ lệch chuẩn hoặc thông tin vùng xung quanh pixel.

**Đặc trưng của bước này:**

- Chuyển ảnh đầu vào thành dữ liệu có thể đưa vào thuật toán học máy.
- Giúp mô hình phân biệt tốt hơn giữa vùng tế bào và vùng nền.
- Đặc trưng lân cận giúp giảm ảnh hưởng của nhiễu pixel đơn lẻ.
- Chất lượng đặc trưng ảnh hưởng trực tiếp đến kết quả phân cụm.

#### 2.2. Phân cụm bằng K-Means

K-Means được sử dụng để nhóm các pixel có đặc trưng tương đồng vào cùng một cụm. Trong bài toán segmentation tế bào, các cụm sau khi phân nhóm sẽ được ánh xạ thành hai nhóm chính: **vùng tế bào** và **vùng nền**.

Sau khi phân cụm, cụm có đặc điểm phù hợp với tế bào được chọn để tạo mask segmentation.

**Đặc trưng:**

- Không yêu cầu nhãn pixel thủ công.
- Phù hợp với dữ liệu chỉ có ảnh đầu vào và nhãn số lượng tế bào ở mức ảnh.
- Dễ triển khai và có tốc độ xử lý tương đối nhanh.
- Kết quả phụ thuộc vào số cụm K, cách chuẩn hóa đặc trưng và chất lượng tiền xử lý.
- Có thể nhầm lẫn nếu tế bào và nền có phân bố cường độ gần giống nhau.

#### 2.3. Hậu xử lý mask

Kết quả phân cụm thường còn nhiễu, biên chưa mượt hoặc xuất hiện các vùng nhỏ không phải tế bào. Vì vậy, các bước hậu xử lý được áp dụng để cải thiện chất lượng mask trước khi đếm.

Các kỹ thuật hậu xử lý gồm:

- Loại bỏ vùng nhỏ không phải tế bào.
- Làm mượt biên đối tượng.
- Lấp các lỗ nhỏ bên trong vùng tế bào.
- Áp dụng các phép toán hình thái học như erosion, dilation, opening hoặc closing.

**Đặc trưng:**

- Giảm nhiễu trong mask.
- Làm kết quả segmentation ổn định hơn.
- Cải thiện độ chính xác khi đếm tế bào.
- Phụ thuộc vào kích thước kernel và ngưỡng lọc đối tượng nhỏ.

#### 2.4. So sánh với nhãn thật

Số lượng tế bào dự đoán được so sánh với nhãn thật. Trong bộ dữ liệu, nhãn thật được mã hóa trong tên file, do đó có thể trích xuất số lượng tế bào thực tế từ tên ảnh.

Kết quả đánh giá được thực hiện bằng cách so sánh:

- Số lượng tế bào dự đoán.
- Số lượng tế bào thực tế.
- Sai số giữa dự đoán và nhãn thật.

**Đặc trưng:**

- Đánh giá trực tiếp hiệu quả của pipeline segmentation và counting.
- Cho phép so sánh định lượng giữa các phương pháp.
- Phù hợp khi không có ground truth mask chi tiết.
- Tập trung vào mục tiêu cuối cùng của bài toán là đếm đúng số lượng tế bào.

### 3. Nhận xét chung

Nhánh Traditional Computer Vision phù hợp với các ảnh có đặc điểm ổn định, độ tương phản rõ và ít biến thiên giữa các mẫu. Phương pháp này có ưu điểm là dễ giải thích, dễ kiểm soát từng bước xử lý, nhưng nhạy với các tham số như kích thước kernel, ngưỡng threshold và điều kiện ánh sáng.

Nhánh Machine Learning linh hoạt hơn vì có thể phân nhóm pixel dựa trên nhiều loại đặc trưng khác nhau. Tuy nhiên, hiệu quả của phương pháp phụ thuộc nhiều vào cách chọn đặc trưng, số cụm K và các bước hậu xử lý mask.
