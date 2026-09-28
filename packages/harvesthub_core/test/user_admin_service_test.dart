import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

void main() {
  group('UserAdminService Unit & Integration Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late UserAdminService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = UserAdminService(firestore: fakeFirestore);
    });

    test('deactivateUser blocks customer, saves reason and timestamp', () async {
      await fakeFirestore.collection('users').doc('user_cust_1').set({
        'name': 'John Customer',
        'email': 'john@example.com',
        'phone': '123456789',
        'address': 'District 1, HCMC',
        'role': Roles.customer,
        'isActive': true,
        'createdAt': Timestamp.now(),
      });

      await service.deactivateUser(
        uid: 'user_cust_1',
        reason: 'Violation of marketplace purchasing policy',
        role: Roles.customer,
      );

      final userDoc =
          await fakeFirestore.collection('users').doc('user_cust_1').get();
      expect(userDoc.data()!['isActive'], isFalse);
      expect(
        userDoc.data()!['deactivation_reason'],
        'Violation of marketplace purchasing policy',
      );
      expect(userDoc.data()!['activationNoticePending'], isFalse);
      expect(userDoc.data()!['deactivatedAt'], isNotNull);
    });

    test('deactivateUser blocks farmer on both users and farmers collections',
        () async {
      await fakeFirestore.collection('users').doc('farmer_1').set({
        'name': 'Farmer Green',
        'email': 'green@farm.com',
        'phone': '0987654321',
        'address': 'Da Lat, Lam Dong',
        'role': Roles.farmer,
        'isActive': true,
        'createdAt': Timestamp.now(),
      });

      await fakeFirestore.collection('farmers').doc('farmer_1').set({
        'userId': 'farmer_1',
        'businessName': 'Green Farm Organics',
        'area': 'Da Lat',
        'rating': 4.9,
        'isActive': true,
        'createdAt': Timestamp.now(),
      });

      await service.deactivateUser(
        uid: 'farmer_1',
        reason: 'Expired food safety certification',
        role: Roles.farmer,
      );

      final userDoc =
          await fakeFirestore.collection('users').doc('farmer_1').get();
      final farmerDoc =
          await fakeFirestore.collection('farmers').doc('farmer_1').get();

      expect(userDoc.data()!['isActive'], isFalse);
      expect(userDoc.data()!['deactivation_reason'],
          'Expired food safety certification');

      expect(farmerDoc.data()!['isActive'], isFalse);
      expect(farmerDoc.data()!['deactivation_reason'],
          'Expired food safety certification');
    });

    test('deactivateUser throws ArgumentError if reason is blank', () async {
      expect(
        () => service.deactivateUser(
          uid: 'user_cust_1',
          reason: '   ',
          role: Roles.customer,
        ),
        throwsArgumentError,
      );
    });

    test('activateUser restores active status and queues pending reactivation notice',
        () async {
      await fakeFirestore.collection('users').doc('user_cust_2').set({
        'name': 'Jane Doe',
        'email': 'jane@example.com',
        'phone': '0911223344',
        'address': 'Binh Thanh, HCMC',
        'role': Roles.customer,
        'isActive': false,
        'deactivation_reason': 'Suspicious login activity',
        'createdAt': Timestamp.now(),
      });

      await service.activateUser(uid: 'user_cust_2', role: Roles.customer);

      final userDoc =
          await fakeFirestore.collection('users').doc('user_cust_2').get();
      expect(userDoc.data()!['isActive'], isTrue);
      expect(userDoc.data()!['deactivation_reason'], isNull);
      expect(userDoc.data()!['activationNoticePending'], isTrue);
    });

    test('fetchUsersPage supports role filtering and pagination', () async {
      final now = DateTime.now();

      for (var i = 1; i <= 5; i++) {
        await fakeFirestore.collection('users').doc('cust_$i').set({
          'name': 'Customer $i',
          'email': 'cust$i@mail.com',
          'phone': '090000000$i',
          'address': 'City',
          'role': Roles.customer,
          'isActive': true,
          'createdAt': Timestamp.fromDate(now.subtract(Duration(minutes: i))),
        });
      }

      for (var i = 1; i <= 3; i++) {
        await fakeFirestore.collection('users').doc('farm_$i').set({
          'name': 'Farmer $i',
          'email': 'farm$i@mail.com',
          'phone': '091000000$i',
          'address': 'Countryside',
          'role': Roles.farmer,
          'isActive': i % 2 == 0,
          'deactivation_reason': i % 2 != 0 ? 'Payment issue' : null,
          'createdAt':
              Timestamp.fromDate(now.subtract(Duration(minutes: 10 + i))),
        });
      }

      // 1. Fetch only Farmers
      final farmerResult = await service.fetchUsersPage(
        limit: 10,
        role: 'Farmers',
      );
      expect(farmerResult.users.length, 3);
      expect(farmerResult.users.every((u) => u.role == Roles.farmer), isTrue);

      // 2. Fetch only Customers
      final custResult = await service.fetchUsersPage(
        limit: 3,
        role: 'Customers',
      );
      expect(custResult.users.length, 3);
      expect(custResult.hasMore, isTrue);

      // 3. Search query filter
      final searchResult = await service.fetchUsersPage(
        limit: 10,
        searchQuery: 'Customer 2',
      );
      expect(searchResult.users.length, 1);
      expect(searchResult.users.first.email, 'cust2@mail.com');

      // 4. Status filter: Deactivated
      final deactResult = await service.fetchUsersPage(
        limit: 10,
        status: 'Deactivated',
      );
      expect(deactResult.users.every((u) => !u.isActive), isTrue);
    });

    test('getUserDetails returns full user and farmer details', () async {
      await fakeFirestore.collection('users').doc('farmer_detail_1').set({
        'name': 'Farmer Bob',
        'email': 'bob@farm.com',
        'phone': '0944556677',
        'address': 'Can Tho',
        'role': Roles.farmer,
        'isActive': true,
        'createdAt': Timestamp.now(),
      });

      await fakeFirestore.collection('farmers').doc('farmer_detail_1').set({
        'userId': 'farmer_detail_1',
        'businessName': 'Bob Fruit Orchards',
        'description': 'Fresh tropical fruits from Mekong Delta',
        'area': 'Can Tho',
        'rating': 4.7,
        'isActive': true,
        'createdAt': Timestamp.now(),
      });

      final detail = await service.getUserDetails('farmer_detail_1');
      expect(detail.user.name, 'Farmer Bob');
      expect(detail.farmerProfile, isNotNull);
      expect(detail.farmerProfile!.businessName, 'Bob Fruit Orchards');
    });

    test('getFarmersWithExcessiveViolations identifies farmers with 3 or more strikes', () async {
      await fakeFirestore.collection('users').doc('farmer_violator_1').set({
        'name': 'Violating Farmer',
        'email': 'violator@farm.com',
        'phone': '0901234567',
        'address': 'Da Lat',
        'role': Roles.farmer,
        'isActive': true,
        'violationStrikes': 3,
        'status': 'active',
        'createdAt': Timestamp.now(),
      });

      await fakeFirestore.collection('users').doc('farmer_normal_1').set({
        'name': 'Good Farmer',
        'email': 'good@farm.com',
        'phone': '0907654321',
        'address': 'Da Lat',
        'role': Roles.farmer,
        'isActive': true,
        'violationStrikes': 1,
        'status': 'active',
        'createdAt': Timestamp.now(),
      });

      final violators = await service.getFarmersWithExcessiveViolations(minStrikes: 3);
      expect(violators.length, 1);
      expect(violators.first.uid, 'farmer_violator_1');
      expect(violators.first.violationStrikes, 3);
    });

    test('banFarmerForViolations updates user and farmer status to banned and deactivated', () async {
      await fakeFirestore.collection('users').doc('farmer_to_ban').set({
        'name': 'Bad Farmer',
        'email': 'bad@farm.com',
        'phone': '0909999999',
        'address': 'Lam Dong',
        'role': Roles.farmer,
        'isActive': true,
        'status': 'active',
        'violationStrikes': 3,
        'createdAt': Timestamp.now(),
      });

      await fakeFirestore.collection('farmers').doc('farmer_to_ban').set({
        'userId': 'farmer_to_ban',
        'businessName': 'Bad Farm',
        'area': 'Lam Dong',
        'rating': 3.5,
        'isActive': true,
        'violationStrikes': 3,
        'createdAt': Timestamp.now(),
      });

      await service.banFarmerForViolations(uid: 'farmer_to_ban');

      final userDoc = await fakeFirestore.collection('users').doc('farmer_to_ban').get();
      final farmerDoc = await fakeFirestore.collection('farmers').doc('farmer_to_ban').get();

      expect(userDoc.data()!['isActive'], isFalse);
      expect(userDoc.data()!['status'], 'banned');
      expect(userDoc.data()!['deactivationReason'], contains('3'));

      expect(farmerDoc.data()!['isActive'], isFalse);
      expect(farmerDoc.data()!['status'], 'banned');
    });

    test('approveFarmer activates farmer and updates status to approved', () async {
      await fakeFirestore.collection('users').doc('farmer_pending_1').set({
        'name': 'Pending Farmer',
        'email': 'pending@farm.com',
        'phone': '0901234567',
        'address': 'Da Lat',
        'role': Roles.farmer,
        'isActive': false,
        'status': 'pending_approval',
        'createdAt': Timestamp.now(),
      });

      await fakeFirestore.collection('farmers').doc('farmer_pending_1').set({
        'userId': 'farmer_pending_1',
        'businessName': 'Pending Farm',
        'area': 'Da Lat',
        'rating': 5.0,
        'isActive': false,
        'approvalStatus': 'pending_approval',
        'status': 'pending_approval',
        'createdAt': Timestamp.now(),
      });

      await service.approveFarmer(uid: 'farmer_pending_1');

      final userDoc = await fakeFirestore.collection('users').doc('farmer_pending_1').get();
      final farmerDoc = await fakeFirestore.collection('farmers').doc('farmer_pending_1').get();

      expect(userDoc.data()!['isActive'], isTrue);
      expect(userDoc.data()!['status'], 'active');
      expect(userDoc.data()!['approvedAt'], isNotNull);
      expect(userDoc.data()!['activationNoticePending'], isTrue);

      expect(farmerDoc.data()!['isActive'], isTrue);
      expect(farmerDoc.data()!['status'], 'approved');
      expect(farmerDoc.data()!['approvalStatus'], 'approved');
      expect(farmerDoc.data()!['approvedAt'], isNotNull);
    });

    test('fetchUsersPage filters by New Users / pending_approval status', () async {
      await fakeFirestore.collection('users').doc('user_approved').set({
        'name': 'Approved User',
        'email': 'approved@test.com',
        'phone': '0901111111',
        'address': 'Da Lat',
        'role': Roles.farmer,
        'isActive': true,
        'status': 'active',
        'createdAt': Timestamp.now(),
      });

      await fakeFirestore.collection('users').doc('user_pending').set({
        'name': 'New Pending Farmer',
        'email': 'pending2@test.com',
        'phone': '0902222222',
        'address': 'Da Lat',
        'role': Roles.farmer,
        'isActive': false,
        'status': 'pending_approval',
        'createdAt': Timestamp.now(),
      });

      final result = await service.fetchUsersPage(status: 'New Users');
      expect(result.users.length, 1);
      expect(result.users.first.uid, 'user_pending');
      expect(result.users.first.status, 'pending_approval');
    });
  });
}
