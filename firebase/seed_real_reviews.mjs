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
  'Sarah Jenkins', 'David Nguyen', 'Emily Watson', 'James Miller', 
  'Jessica Taylor', 'Michael Chen', 'Hannah Scott', 'Robert Wilson', 
  'Amanda Brooks', 'Daniel Lee', 'Olivia Clark', 'Marcus Johnson', 
  'Grace Bennett', 'Lucas Martin', 'Sophie Anderson', 'Alexander Wright'
];

const productCommentTemplates = [
  'Produce is remarkably fresh, crisp and naturally sweet, harvested early this morning!',
  'Outstanding quality, thoughtfully packaged in eco-friendly paper bags. Highly recommended!',
  'Very fresh produce directly from local farm! Great taste, crisp leaves and excellent value.',
  'Naturally sweet fruit with no chemicals. Gives our family complete peace of mind every day.',
  'Extremely fair prices for farm-gate produce. Pickup point was easy to find and staff was welcoming.',
  'Delivered promptly, fresh leaves with zero wilting. 5 stars for quality and cleanliness!',
  'Consistent quality across all batches. Greens stay crisp in the refrigerator for days.',
  'Authentic organic taste, retaining wonderful crunch and farm sweetness throughout the week.',
  'Delicious and naturally sweet, perfect for morning salads, roasting, and smoothies.',
  'True farm-to-table freshness, neatly packed, with exact weights and premium condition.'
];

const productTagOptions = [
  '🌿 Super Fresh', '⭐ Top Quality', '🌱 100% Organic', 
  '📦 Neat Packaging', '👍 Highly Recommend', '😋 Delicious & Crisp',
  '💰 Great Value', '🍃 Clean & Safe'
];

const farmerCommentTemplates = [
  'The farm owner is extremely friendly and attentive. Pickup station was convenient and order was ready.',
  'Immaculate farm with transparent organic farming methods. The team was prompt and welcoming.',
  'Pickup station was super easy to locate. The farmer was exceptionally friendly, knowledgeable and courteous!',
  'Produce is always well sorted and packed ahead of arrival. Seamless experience for busy shoppers.',
  'Great organic farm! Authentic quality, fresh harvest every morning and wonderful customer care.',
  'Harvested same-day, vibrant and crisp. The farmer provided detailed storage and preparation tips.',
  'Top-notch farm with fair prices, passionate growers, and genuinely honest hospitality.'
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
        authorId: `seed_cust_${(r % 10) + 1}`,
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
        authorId: `seed_cust_${(r % 10) + 1}`,
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
