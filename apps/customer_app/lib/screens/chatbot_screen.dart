import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'product_detail_sheet.dart';

class ChatbotChatMessage {
  final bool isUser;
  final String text;
  final String category;
  final List<String> pinnedProductIds;
  final DateTime timestamp;

  const ChatbotChatMessage({
    required this.isUser,
    required this.text,
    this.category = 'General',
    this.pinnedProductIds = const [],
    required this.timestamp,
  });
}

class ChatbotScreen extends StatefulWidget {
  final String? customApiKey;
  final ProductService? productService;

  const ChatbotScreen({
    super.key,
    this.customApiKey,
    this.productService,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final FaqService _faqService;
  late final Stream<List<Product>> _productsStream;
  List<Product> _latestProducts = [];

  final List<ChatbotChatMessage> _messages = [
    ChatbotChatMessage(
      isUser: false,
      text: FaqService.greeting,
      category: 'General',
      timestamp: DateTime.now(),
    ),
  ];

  bool _isThinking = false;


  @override
  void initState() {
    super.initState();
    _faqService = FaqService(apiKey: widget.customApiKey);
    _productsStream = (widget.productService ?? ProductService()).streamActiveProducts();
    _productsStream.listen((prods) {
      if (mounted) {
        setState(() {
          _latestProducts = prods;
        });
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? presetQuery]) async {
    final text = presetQuery ?? _inputController.text.trim();
    if (text.isEmpty || _isThinking) return;

    if (presetQuery == null) {
      _inputController.clear();
    }

    setState(() {
      _messages.add(
        ChatbotChatMessage(
          isUser: true,
          text: text,
          timestamp: DateTime.now(),
        ),
      );
      _isThinking = true;
    });
    _scrollToBottom();

    final chatHistory = _messages
        .take(_messages.length - 1)
        .map((m) => {
              'role': m.isUser ? 'user' : 'model',
              'text': m.text,
            })
        .toList();

    try {
      final aiResult = await _faqService.getAiResponse(
        text,
        liveProducts: _latestProducts,
        chatHistory: chatHistory,
      );

      if (mounted) {
        setState(() {
          _messages.add(
            ChatbotChatMessage(
              isUser: false,
              text: aiResult.text,
              category: aiResult.category,
              pinnedProductIds: aiResult.pinnedProductIds,
              timestamp: DateTime.now(),
            ),
          );
          _isThinking = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatbotChatMessage(
              isUser: false,
              text: _faqService.answer(text),
              category: 'General',
              timestamp: DateTime.now(),
            ),
          );
          _isThinking = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _messages.add(
        ChatbotChatMessage(
          isUser: false,
          text: FaqService.greeting,
          category: 'General',
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  void _openProductDetail(Product product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductDetailSheet(
        product: product,
        categoryName: product.categoryId,
      ),
    );
  }

  Future<void> _quickAddToCart(Product product) async {
    try {
      await context.read<CartController>().addToCart(product, 1);
      if (mounted) {
        TopToast.show(context, 'Added ${product.name} to basket!');
      }
    } catch (_) {
      if (mounted) {
        TopToast.show(context, 'Could not add product', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');

    return Scaffold(
      backgroundColor: HhColors.bg,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: HhColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Farm Assistant',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Live Inventory Context',
                  style: TextStyle(
                    fontSize: 11,
                    color: HhColors.text.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Clear Chat',
            onPressed: _messages.length <= 1 ? null : _clearChat,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopicSuggestions(),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length + (_isThinking ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isThinking) {
                    return _buildThinkingIndicator();
                  }

                  final message = _messages[index];
                  return _buildMessageBubble(message, timeFormat);
                },
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicSuggestions() {
    return Container(
      height: 52,
      color: Colors.white,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: FaqService.quickTopics.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final topic = FaqService.quickTopics[index];
          return ActionChip(
            avatar: Text(topic.icon, style: const TextStyle(fontSize: 13)),
            label: Text(
              topic.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: HhColors.text,
              ),
            ),
            backgroundColor: HhColors.sageLight.withValues(alpha: 0.5),
            side: BorderSide(
              color: HhColors.primary.withValues(alpha: 0.2),
            ),
            onPressed: _isThinking ? null : () => _sendMessage(topic.prompt),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(ChatbotChatMessage message, DateFormat timeFormat) {
    final isUser = message.isUser;

    /* Find matching pinned products */
    final pinnedProducts = <Product>[];
    if (!isUser && message.pinnedProductIds.isNotEmpty && _latestProducts.isNotEmpty) {
      for (final id in message.pinnedProductIds) {
        final match = _latestProducts.where((p) => p.id == id).firstOrNull;
        if (match != null) {
          pinnedProducts.add(match);
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(right: 8, top: 4),
              child: const CircleAvatar(
                radius: 16,
                backgroundColor: HhColors.primary,
                child: Icon(
                  Icons.eco_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isUser && message.category.isNotEmpty && message.category != 'General')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0, left: 4.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: HhColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'TOPIC: ${message.category.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: HhColors.primary,
                        ),
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? HhColors.primary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment:
                        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.4,
                          color: isUser ? Colors.white : HhColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeFormat.format(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: isUser
                              ? Colors.white.withValues(alpha: 0.7)
                              : HhColors.text.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isUser && pinnedProducts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Column(
                    children: pinnedProducts
                        .map((p) => _buildPinnedProductCard(p))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildPinnedProductCard(Product p) {
    final isOutOfStock = p.stockQty <= 0;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HhColors.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: HhColors.primary.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 50,
              height: 50,
              child: ProductImage(p.imageUrl),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isOutOfStock ? HhColors.danger : HhColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isOutOfStock ? 'OUT OF STOCK' : 'PINNED ITEM',
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Text(
                  '\$${(p.price / 100).toStringAsFixed(2)} / ${p.unit} • ${p.farmerName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: HhColors.text.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.info_outline_rounded, color: HhColors.primary, size: 20),
                tooltip: 'View Details',
                onPressed: () => _openProductDetail(p),
              ),
              if (!isOutOfStock)
                IconButton(
                  icon: const Icon(Icons.add_shopping_cart_rounded, color: HhColors.accent, size: 20),
                  tooltip: 'Add to Basket',
                  onPressed: () => _quickAddToCart(p),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: HhColors.primary,
            child: Icon(
              Icons.eco_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: HhColors.primary,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'AI Sprout is analyzing live store inventory...',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: HhColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              enabled: !_isThinking,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Ask AI about store items, nutrition, or prices...',
                hintStyle: TextStyle(
                  fontSize: 13.5,
                  color: HhColors.text.withValues(alpha: 0.45),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                filled: true,
                fillColor: HhColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 22,
            backgroundColor: _isThinking ? HhColors.muted : HhColors.primary,
            child: IconButton(
              icon: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 18,
              ),
              onPressed: _isThinking ? null : () => _sendMessage(),
            ),
          ),
        ],
      ),
    );
  }
}
