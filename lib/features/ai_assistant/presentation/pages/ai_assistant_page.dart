import 'package:flutter/material.dart';
import '../../data/gemini_service.dart';
import '../../../transactions/data/transaction_service.dart';
import '../../../../core/services/firebase_service.dart';

/// Página del Asistente de IA con Gemini
class AIAssistantPage extends StatefulWidget {
  const AIAssistantPage({super.key});

  @override
  State<AIAssistantPage> createState() => _AIAssistantPageState();
}

class _AIAssistantPageState extends State<AIAssistantPage> {
  final _geminiService = GeminiService();
  final _transactionService = TransactionService();
  final _firebaseService = FirebaseService();
  final _scrollController = ScrollController();
  final _messageController = TextEditingController();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isLoadingAdvice = false;

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add({
        'text':
            '¡Hola! 👋 Soy SAY, tu asistente financiero inteligente. '
            'Puedo ayudarte con:\n\n'
            '• Análisis de tu situación financiera\n'
            '• Consejos personalizados de ahorro\n'
            '• Sugerencias de presupuesto\n'
            '• Responder preguntas sobre finanzas\n\n'
            '¿En qué puedo ayudarte hoy?',
        'isUser': false,
        'timestamp': DateTime.now(),
      });
    });
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

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    setState(() {
      _messages.add({
        'text': message,
        'isUser': true,
        'timestamp': DateTime.now(),
      });
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await _geminiService.chat(message);

      if (mounted) {
        setState(() {
          _messages.add({
            'text': response,
            'isUser': false,
            'timestamp': DateTime.now(),
          });
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'text': 'Lo siento, hubo un error. Intenta de nuevo.',
            'isUser': false,
            'timestamp': DateTime.now(),
          });
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _getFinancialAdvice() async {
    setState(() => _isLoadingAdvice = true);

    try {
      final user = _firebaseService.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final summary = await _transactionService.getMonthSummary(
        user.uid,
        month: month,
      );

      final totalIncome = summary['totalIncome'] ?? 0.0;
      final totalExpenses = summary['totalExpenses'] ?? 0.0;
      final balance = summary['balance'] ?? 0.0;
      final savingsPercentage = totalIncome > 0
          ? (balance / totalIncome) * 100
          : 0.0;

      setState(() {
        _messages.add({
          'text': 'Analizar mi situacion financiera...',
          'isUser': true,
          'timestamp': DateTime.now(),
        });
      });
      _scrollToBottom();

      final advice = await _geminiService.getFinancialAdvice(
        totalIncome: totalIncome,
        totalExpenses: totalExpenses,
        savingsPercentage: savingsPercentage,
      );

      if (mounted) {
        setState(() {
          _messages.add({
            'text': advice,
            'isUser': false,
            'timestamp': DateTime.now(),
          });
          _isLoadingAdvice = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'text': 'Error al obtener el análisis. Intenta de nuevo.',
            'isUser': false,
            'timestamp': DateTime.now(),
          });
          _isLoadingAdvice = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistente IA SAY'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: _isLoadingAdvice ? null : _getFinancialAdvice,
            tooltip: 'Obtener consejos personalizados',
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner informativo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  Theme.of(context).primaryColor.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Powered by Google Gemini AI',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          // Lista de mensajes
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessage(message);
                    },
                  ),
          ),

          // Indicador de carga
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Pensando...'),
                ],
              ),
            ),

          // Campo de entrada
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Escribe tu pregunta...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: () => _sendMessage(_messageController.text),
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    final isUser = message['isUser'] as bool;
    final text = message['text'] as String;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? Theme.of(context).primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(0) : null,
            bottomLeft: !isUser ? const Radius.circular(0) : null,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
