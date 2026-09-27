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
  });
}
