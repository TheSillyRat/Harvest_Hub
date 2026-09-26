class FaqService {
  static const greeting =
      'Hello! I am your AI Farm Assistant. How can I help you discover fresh produce today?';

  String answer(String query) {
    final q = query.toLowerCase();
    if (q.contains('delivery') || q.contains('shipping') || q.contains('pickup')) {
      return 'Orders are for pickup at the designated farm distribution hub. No home delivery is available.';
    }
    if (q.contains('payment') || q.contains('pay')) {
      return 'HarvestHub runs simulated orders for testing and demonstration purposes. No real payments are processed.';
    }
    if (q.contains('organic') || q.contains('fresh')) {
      return 'All our local farmers adhere to organic and natural crop growing practices!';
    }
    return 'Thank you for your question! You can browse categories or contact the local farm store directly.';
  }
}
