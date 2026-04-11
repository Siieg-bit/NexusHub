import 'package:flutter/material.dart';
import '../../../core/utils/responsive.dart';

/// Separador de data exibido entre mensagens de dias diferentes no chat.
///
/// Exibe:
/// - "Hoje" para mensagens do dia atual
/// - "Ontem" para mensagens do dia anterior
/// - "DD de Mês" para datas dentro do mesmo ano (ex: "3 de abril")
/// - "DD de Mês de AAAA" para datas de anos anteriores (ex: "15 de março de 2024")
class ChatDateSeparator extends StatelessWidget {
  final DateTime date;

  const ChatDateSeparator({super.key, required this.date});

  static const _months = [
    'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
    'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
  ];

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDay = DateTime(date.year, date.month, date.day);

    if (msgDay == today) return 'Hoje';
    if (msgDay == yesterday) return 'Ontem';

    final month = _months[date.month - 1];
    if (date.year == now.year) {
      return '${date.day} de $month';
    }
    return '${date.day} de $month de ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final label = _formatDate(date);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.s(12)),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: Colors.white.withValues(alpha: 0.08),
              thickness: 1,
            ),
          ),
          SizedBox(width: r.s(10)),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: r.s(12), vertical: r.s(4)),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(r.s(12)),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: r.fs(11),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ),
          SizedBox(width: r.s(10)),
          Expanded(
            child: Divider(
              color: Colors.white.withValues(alpha: 0.08),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Verifica se duas mensagens são de dias diferentes.
/// Usado no itemBuilder para decidir se exibe o separador.
bool shouldShowDateSeparator(DateTime current, DateTime? previous) {
  if (previous == null) return true;
  return current.year != previous.year ||
      current.month != previous.month ||
      current.day != previous.day;
}
