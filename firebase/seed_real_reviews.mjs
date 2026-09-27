import { initializeApp } from 'firebase/app';
import { getFirestore, collection, getDocs, doc, setDoc, updateDoc, Timestamp } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: 'AIzaSyBEoPsJwr0oCeZbIC_OLBTr_udFnx4E2d0',
  projectId: 'harvesthub-c57ec',
  storageBucket: 'harvesthub-c57ec.firebasestorage.app'
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

const reviewerNames = [
  'Thu Ha Le', 'Nguyen Minh Tuấn', 'Tran Thi Mai', 'Hoang Nam', 
  'Le Bich Ngoc', 'Bao Long', 'Pham Duc Huy', 'Kim Ngan', 
  'Thao Nguyen', 'Quoc Bao', 'Thanh Hang', 'Bui Hong Nhung', 
  'David Nguyen', 'Emily Tran', 'Vo Tien Dat', 'Do Quang Khai'
];

const productCommentTemplates = [
  'Rau củ rất tươi ngon, giòn ngọt tự nhiên, thu hoạch sáng sớm giao đúng giờ!',
  'Chất lượng tuyệt vời, đóng gói cẩn thận từng túi giấy thân thiện môi trường, sẽ tiếp tục ủng hộ nông trại.',
  'Very fresh produce directly from local farm! Great taste, crisp leaves and excellent value.',
  'Trái cây ngọt lịm tự nhiên, không ngâm thuốc, rất an tâm cho gia đình sử dụng hàng ngày.',
  'Giá cả cực kỳ hợp lý cho sản phẩm sạch tận vườn, điểm nhận hàng dễ tìm và nhân viên hướng dẫn nhiệt tình.',
  'Delivered promptly, fresh leaves with zero wilting. 5 stars for quality and cleanliness!',
  'Sản phẩm chất lượng đồng đều, rau to xanh mướt, luộc lên nước ngọt lịm.',
  'Nông sản hữu cơ chuẩn vị, để ngăn mát tủ lạnh 4-5 ngày vẫn tươi nguyên giòn ngọt.',
  'Delicious and naturally sweet, perfect for morning salads and smoothies.',
  'Đúng chuẩn tươi từ vườn đến bàn ăn, đóng gói cẩn thận, cân đúng khối lượng.'
];

const productTagOptions = [
  '🌿 Super Fresh', '⭐ Top Quality', '🌱 100% Organic', 
  '📦 Neat Packaging', '👍 Highly Recommend', '😋 Delicious & Crisp',
  '💰 Great Value', '🍃 Clean & Safe'
];

const farmerCommentTemplates = [
  'Chủ vườn rất nhiệt tình và chu đáo, điểm lấy hàng thuận tiện, rau củ đã được chuẩn bị sẵn.',
  'Nông trại sạch đẹp, quy trình canh tác hữu cơ rõ ràng, nhân viên hỗ trợ nhanh nhẹn và niềm nở.',
  'Pickup station was super easy to locate. The farmer was exceptionally friendly, knowledgeable and courteous!',
  'Rau củ lúc nào cũng được chuẩn bị sẵn gọn gàng khi mình ghé lấy. Rất tiện lợi cho người bận rộn.',
  'Great organic farm in Saigon! Authentic quality, fresh harvest every morning and wonderful customer care.',
  'Sản phẩm thu hoạch trong ngày, tươi roi rói, chủ vườn tư vấn cách bảo quản rất chi tiết.',
  'Nông trại chất lượng cao, giá thành hợp lý, nông dân tử tế và thân thiện.'
];

const farmerTagOptions = [
  '👨‍🌾 Friendly Farmer', '⚡ Fast Pickup', '📍 Easy to Find',
  '🌿 Top Quality', '📦 Well Packaged', '🔄 Will Revisit',
  '💚 Honest Service'
];

function getRandomItems(arr, count) {
  const shuffled = [...arr].sort(() => 0.5 - Math.random());
  return shuffled.slice(0, count);
}

function getRandomRating() {
  const ratings = [5.0, 5.0, 4.8, 5.0, 4.5, 4.7, 4.9, 4.0, 5.0];
  return ratings[Math.floor(Math.random() * ratings.length)];
}

async function main() {
  console.log('=== Starting Real Review & Real Count Seeding for HarvestHub ===');

  // 1. Seed reviews for all Farmers
  const farmersCol = collection(db, 'farmers');
  const farmersSnap = await getDocs(farmersCol);
  console.log(`Found ${farmersSnap.size} farmers to seed reviews...`);

  let farmerIndex = 0;
  for (const farmerDoc of farmersSnap.docs) {
    farmerIndex++;
    const farmerId = farmerDoc.id;
    const farmerData = farmerDoc.data();
    const farmerName = farmerData.businessName || farmerData.farmerName || 'Organic Farm';

    // 4 to 8 reviews per farmer
    const reviewCount = 4 + ((farmerIndex * 3) % 5);
    const reviews = [];
    let totalStars = 0;

    for (let r = 0; r < reviewCount; r++) {
      const reviewId = `seed_frev_${farmerId.slice(0, 8)}_${r + 1}`;
      const author = reviewerNames[(farmerIndex + r * 2) % reviewerNames.length];
      const comment = farmerCommentTemplates[(farmerIndex + r * 3) % farmerCommentTemplates.length];
      const tags = getRandomItems(farmerTagOptions, 2 + (r % 2));
      const rating = getRandomRating();
      totalStars += rating;

      const daysAgo = 1 + (r * 3) + (farmerIndex % 4);
      const createdAt = Timestamp.fromDate(new Date(Date.now() - daysAgo * 24 * 60 * 60 * 1000));

      const reviewData = {
        id: reviewId,
        farmerId,
        farmerName,
        authorId: `customer_${(r % 10) + 1}`,
        authorName: author,
        authorAvatar: '',
        rating,
        comment,
        tags,
        createdAt,
        isDemo: true
      };

      await setDoc(doc(db, 'farmers', farmerId, 'reviews', reviewId), reviewData);
      reviews.push(reviewData);
    }

    const avgRating = parseFloat((totalStars / reviewCount).toFixed(1));
    await updateDoc(doc(db, 'farmers', farmerId), {
      rating: avgRating,
      reviewCount: reviewCount
    });

    console.log(`  [${farmerIndex}/${farmersSnap.size}] Farmer "${farmerName}": ${reviewCount} reviews, rating: ${avgRating}`);
  }

  // 2. Seed reviews for all Products
  const productsCol = collection(db, 'products');
  const productsSnap = await getDocs(productsCol);
  console.log(`\nFound ${productsSnap.size} products to seed reviews...`);

  let productIndex = 0;
  for (const prodDoc of productsSnap.docs) {
    productIndex++;
    const productId = prodDoc.id;
    const prodData = prodDoc.data();
    const productName = prodData.name || 'Produce';

    // 3 to 7 reviews per product
    const reviewCount = 3 + ((productIndex * 2) % 5);
    const reviews = [];
    let totalStars = 0;

    for (let r = 0; r < reviewCount; r++) {
      const reviewId = `seed_prev_${productId.slice(0, 10)}_${r + 1}`;
      const author = reviewerNames[(productIndex + r * 3) % reviewerNames.length];
      const comment = productCommentTemplates[(productIndex + r * 2) % productCommentTemplates.length];
      const tags = getRandomItems(productTagOptions, 2 + (r % 2));
      const rating = getRandomRating();
      totalStars += rating;

      const daysAgo = 1 + (r * 2) + (productIndex % 5);
      const createdAt = Timestamp.fromDate(new Date(Date.now() - daysAgo * 24 * 60 * 60 * 1000));

      const reviewData = {
        id: reviewId,
        productId,
        productName,
        authorId: `customer_${(r % 10) + 1}`,
        authorName: author,
        authorAvatar: '',
        rating,
        comment,
        tags,
        createdAt,
        isDemo: true
      };

      await setDoc(doc(db, 'products', productId, 'reviews', reviewId), reviewData);
      reviews.push(reviewData);
    }

    const avgRating = parseFloat((totalStars / reviewCount).toFixed(1));
    await updateDoc(doc(db, 'products', productId), {
      rating: avgRating,
      reviewCount: reviewCount
    });

    if (productIndex % 10 === 0 || productIndex === productsSnap.size) {
      console.log(`  [${productIndex}/${productsSnap.size}] Seeded products up to "${productName}": ${reviewCount} reviews, rating: ${avgRating}`);
    }
  }

  console.log('\n=== All Real Reviews and Real Counts Successfully Seeded to Firestore! ===');
  process.exit(0);
}

main().catch((err) => {
  console.error('Error during review seeding:', err);
  process.exit(1);
});
