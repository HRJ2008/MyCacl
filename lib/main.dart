import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const CalclyApp());
}

class CalclyApp extends StatelessWidget {
  const CalclyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calcly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006CFF)),
        fontFamily: 'Segoe UI',
        useMaterial3: true,
      ),
      home: const CalculatorScreen(),
    );
  }
}

class HistoryEntry {
  const HistoryEntry(this.expression, this.result);

  final String expression;
  final String result;
}

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  static const add = '+';
  static const subtract = '\u2212';
  static const multiply = '\u00d7';
  static const divide = '\u00f7';

  final FocusNode _focusNode = FocusNode();
  String _currentValue = '';
  String _expression = '';
  double? _storedValue;
  String? _pendingOperator;
  bool _waitingForNextValue = false;
  double? _memoryValue;
  int _activeTab = 0;
  final List<HistoryEntry> _history = [];
  final List<HistoryEntry> _memoryHistory = [];

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool get _hasValue => _currentValue.isNotEmpty && _currentValue != 'Error';

  double get _currentNumber => _hasValue ? double.parse(_currentValue) : 0;

  void _capList(List<HistoryEntry> list) {
    if (list.length > 5) {
      list.removeRange(5, list.length);
    }
  }

  String _compact(double value) {
    if (value.isNaN || value.isInfinite) {
      return 'Error';
    }
    if (value == 0) {
      return '0';
    }
    final fixed = value.toStringAsFixed(10);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _format(double value) {
    if (value.isNaN || value.isInfinite) {
      return 'Error';
    }

    final normalized = value == 0 ? 0.0 : value;
    final sign = normalized < 0 ? '-' : '';
    final raw = _compact(normalized.abs());
    final parts = raw.split('.');
    var whole = parts.first;
    final decimal = parts.length > 1 ? '.${parts.last}' : '';

    if (whole.length <= 3) {
      return '$sign$whole$decimal';
    }

    final lastThree = whole.substring(whole.length - 3);
    whole = whole.substring(0, whole.length - 3);
    final groups = <String>[];
    while (whole.length > 2) {
      groups.insert(0, whole.substring(whole.length - 2));
      whole = whole.substring(0, whole.length - 2);
    }
    if (whole.isNotEmpty) {
      groups.insert(0, whole);
    }
    return '$sign${groups.join(',')},$lastThree$decimal';
  }

  void _setValue(String value) {
    setState(() => _currentValue = value);
  }

  void _inputNumber(String number) {
    setState(() {
      if (_currentValue == 'Error' || _waitingForNextValue) {
        _currentValue = number;
        _waitingForNextValue = false;
      } else {
        _currentValue = _currentValue == '0' ? number : _currentValue + number;
      }

      _expression = _pendingOperator != null && _storedValue != null
          ? '${_format(_storedValue!)} $_pendingOperator'
          : '';
    });
  }

  void _inputDecimal() {
    setState(() {
      if (_currentValue == 'Error' || _waitingForNextValue || _currentValue.isEmpty) {
        _currentValue = '0.';
        _waitingForNextValue = false;
      } else if (!_currentValue.contains('.')) {
        _currentValue += '.';
      }
    });
  }

  double? _calculate(double first, double second, String operator) {
    if (operator == divide && second == 0) {
      setState(() {
        _currentValue = 'Error';
        _storedValue = null;
        _pendingOperator = null;
        _waitingForNextValue = true;
        _expression = '';
      });
      return null;
    }

    if (operator == add) {
      return first + second;
    }
    if (operator == subtract) {
      return first - second;
    }
    if (operator == multiply) {
      return first * second;
    }
    if (operator == divide) {
      return first / second;
    }
    return second;
  }

  void _chooseOperator(String operator) {
    if (!_hasValue) {
      return;
    }

    setState(() {
      final inputValue = _currentNumber;
      if (_pendingOperator != null && !_waitingForNextValue) {
        final result = _calculate(_storedValue!, inputValue, _pendingOperator!);
        if (result == null) {
          return;
        }
        _storedValue = result;
        _currentValue = _compact(result);
      } else {
        _storedValue = inputValue;
      }

      _pendingOperator = operator;
      _waitingForNextValue = true;
      _expression = '${_format(_storedValue!)} $operator';
    });
  }

  void _completeCalculation() {
    if (_pendingOperator == null || _storedValue == null || !_hasValue) {
      return;
    }

    final secondValue = _currentNumber;
    final expression = '${_format(_storedValue!)} $_pendingOperator ${_format(secondValue)} =';
    final result = _calculate(_storedValue!, secondValue, _pendingOperator!);
    if (result == null) {
      return;
    }

    setState(() {
      _currentValue = _compact(result);
      _expression = expression;
      _storedValue = null;
      _pendingOperator = null;
      _waitingForNextValue = true;
      _history.insert(0, HistoryEntry(expression, _format(result)));
      _capList(_history);
    });
  }

  void _clear() {
    setState(() {
      _currentValue = '';
      _storedValue = null;
      _pendingOperator = null;
      _waitingForNextValue = false;
      _expression = '';
    });
  }

  void _backspace() {
    setState(() {
      if (_currentValue == 'Error' || _waitingForNextValue) {
        _currentValue = '';
        _waitingForNextValue = false;
      } else {
        _currentValue = _currentValue.length > 1 ? _currentValue.substring(0, _currentValue.length - 1) : '';
      }
    });
  }

  void _toggleSign() {
    if (!_hasValue || _currentValue == '0') {
      return;
    }
    _setValue(_currentValue.startsWith('-') ? _currentValue.substring(1) : '-$_currentValue');
  }

  void _applyUnary(String action) {
    if (!_hasValue) {
      return;
    }

    final value = _currentNumber;
    double result = value;
    String expression = '';

    if (action == 'percent') {
      result = value / 100;
      expression = '${_format(value)}% =';
    } else if (action == 'reciprocal') {
      if (value == 0) {
        setState(() {
          _currentValue = 'Error';
          _expression = '1 / 0 =';
          _waitingForNextValue = true;
        });
        return;
      }
      result = 1 / value;
      expression = '1 / ${_format(value)} =';
    } else if (action == 'square') {
      result = value * value;
      expression = '${_format(value)}\u00b2 =';
    } else if (action == 'sqrt') {
      if (value < 0) {
        setState(() {
          _currentValue = 'Error';
          _expression = '\u221a${_format(value)} =';
          _waitingForNextValue = true;
        });
        return;
      }
      result = math.sqrt(value);
      expression = '\u221a${_format(value)} =';
    }

    setState(() {
      _currentValue = _compact(result);
      _expression = expression;
      _waitingForNextValue = true;
      _history.insert(0, HistoryEntry(expression, _format(result)));
      _capList(_history);
    });
  }

  void _addMemoryHistory(String expression) {
    if (_memoryValue == null) {
      return;
    }
    _memoryHistory.insert(0, HistoryEntry(expression, _format(_memoryValue!)));
    _capList(_memoryHistory);
  }

  void _memory(String action) {
    setState(() {
      final value = _currentNumber;
      if (action == 'clear') {
        _memoryValue = null;
        _memoryHistory.clear();
      } else if (action == 'recall' && _memoryValue != null) {
        _currentValue = _compact(_memoryValue!);
        _waitingForNextValue = true;
        _expression = '';
      } else if (action == 'add') {
        _memoryValue = (_memoryValue ?? 0) + value;
        _addMemoryHistory('M+ ${_format(value)}');
      } else if (action == 'subtract') {
        _memoryValue = (_memoryValue ?? 0) - value;
        _addMemoryHistory('M\u2212 ${_format(value)}');
      } else if (action == 'store') {
        _memoryValue = value;
        _addMemoryHistory('MS');
      }
    });
  }

  void _clearPanel() {
    setState(() {
      if (_activeTab == 0) {
        _history.clear();
      } else {
        _memoryValue = null;
        _memoryHistory.clear();
      }
    });
  }

  void _showShortcuts() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keyboard shortcuts'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ShortcutLine('0-9', 'Type numbers'),
            _ShortcutLine('+ - * /', 'Choose operator'),
            _ShortcutLine('Enter', 'Calculate result'),
            _ShortcutLine('Backspace', 'Delete last digit'),
            _ShortcutLine('Esc / C', 'Clear display'),
            _ShortcutLine('%', 'Percent'),
            _ShortcutLine('M', 'Switch History / Memory'),
          ],
        ),
      ),
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey.keyLabel;
    if (RegExp(r'^\d$').hasMatch(key)) {
      _inputNumber(key);
      return KeyEventResult.handled;
    }

    if (key == '.') {
      _inputDecimal();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter || key == '=') {
      _completeCalculation();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape || key.toLowerCase() == 'c') {
      _clear();
      return KeyEventResult.handled;
    }

    if (key == '+') _chooseOperator(add);
    if (key == '-') _chooseOperator(subtract);
    if (key == '*' || key.toLowerCase() == 'x') _chooseOperator(multiply);
    if (key == '/') _chooseOperator(divide);
    if (['+', '-', '*', '/', 'x', 'X'].contains(key)) {
      return KeyEventResult.handled;
    }

    if (key == '%') {
      _applyUnary('percent');
      return KeyEventResult.handled;
    }

    if (key.toLowerCase() == 'm') {
      setState(() => _activeTab = _activeTab == 0 ? 1 : 0);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) => _handleKey(_focusNode, event),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFAFDFF), Color(0xFFEEF6FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 20, 32, 26),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 980;
                      final calculator = _CalculatorArea(
                        expression: _expression,
                        display: _currentValue.isEmpty || _currentValue == 'Error'
                            ? _currentValue
                            : _format(_currentNumber),
                        onNumber: _inputNumber,
                        onDecimal: _inputDecimal,
                        onOperator: _chooseOperator,
                        onAction: (action) {
                          if (action == 'clear') _clear();
                          if (action == 'backspace') _backspace();
                          if (action == 'equals') _completeCalculation();
                          if (action == 'toggle') _toggleSign();
                          if (['percent', 'reciprocal', 'square', 'sqrt'].contains(action)) {
                            _applyUnary(action);
                          }
                        },
                        onMemory: _memory,
                        onShortcuts: _showShortcuts,
                      );
                      final panel = _SidePanel(
                        activeTab: _activeTab,
                        history: _history,
                        memoryHistory: _memoryHistory,
                        onTab: (index) => setState(() => _activeTab = index),
                        onClear: _clearPanel,
                        onShortcuts: _showShortcuts,
                      );

                      return Column(
                        children: [
                          _Header(onShortcuts: _showShortcuts),
                          const SizedBox(height: 16),
                          Expanded(
                            child: isWide
                                ? Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(child: calculator),
                                      const SizedBox(width: 22),
                                      SizedBox(width: 300, child: panel),
                                    ],
                                  )
                                : ListView(
                                    children: [
                                      calculator,
                                      const SizedBox(height: 22),
                                      SizedBox(height: 340, child: panel),
                                    ],
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onShortcuts});

  final VoidCallback onShortcuts;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PopupMenuButton<String>(
          tooltip: 'Open menu',
          onSelected: (_) => onShortcuts(),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'shortcuts', child: Text('Keyboard shortcuts')),
          ],
          child: const SizedBox(
            width: 29,
            height: 29,
            child: Icon(Icons.menu_rounded, size: 28, color: Color(0xFF0B1729)),
          ),
        ),
        const SizedBox(width: 11),
        Container(
          width: 33,
          height: 33,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: [Color(0xFF3BB2FF), Color(0xFF006CFF), Color(0xFF0042C8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [BoxShadow(color: Color(0x330064FF), blurRadius: 22, offset: Offset(0, 10))],
          ),
          child: const GridView.count(
            crossAxisCount: 2,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              Center(child: Text('+', style: _LogoTextStyle())),
              Center(child: Text('-', style: _LogoTextStyle())),
              Center(child: Text('x', style: _LogoTextStyle())),
              Center(child: Text('\u00f7', style: _LogoTextStyle())),
            ],
          ),
        ),
        const SizedBox(width: 11),
        const Text(
          'Calcly',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: Color(0xFF061326)),
        ),
      ],
    );
  }
}

class _LogoTextStyle extends TextStyle {
  const _LogoTextStyle()
      : super(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, height: 1);
}

class _CalculatorArea extends StatelessWidget {
  const _CalculatorArea({
    required this.expression,
    required this.display,
    required this.onNumber,
    required this.onDecimal,
    required this.onOperator,
    required this.onAction,
    required this.onMemory,
    required this.onShortcuts,
  });

  final String expression;
  final String display;
  final ValueChanged<String> onNumber;
  final VoidCallback onDecimal;
  final ValueChanged<String> onOperator;
  final ValueChanged<String> onAction;
  final ValueChanged<String> onMemory;
  final VoidCallback onShortcuts;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GlassCard(
          height: 112,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(expression, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              FittedBox(
                alignment: Alignment.centerRight,
                fit: BoxFit.scaleDown,
                child: Text(
                  display,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 58, fontWeight: FontWeight.w800, color: Color(0xFF061326), height: 0.95),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final item in const [
              ('MC', 'clear'),
              ('MR', 'recall'),
              ('M+', 'add'),
              ('M\u2212', 'subtract'),
              ('MS', 'store'),
            ])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.5),
                  child: _CalcButton(label: item.$1, height: 41, fontSize: 14, onTap: () => onMemory(item.$2)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 11),
        Expanded(
          child: GridView.count(
            crossAxisCount: 4,
            childAspectRatio: 2.35,
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _CalcButton(label: '%', isOperator: true, onTap: () => onAction('percent')),
              _CalcButton(label: 'CE', isOperator: true, onTap: () => onAction('clear')),
              _CalcButton(label: 'C', isOperator: true, onTap: () => onAction('clear')),
              _CalcButton(label: '\u232b', isOperator: true, onTap: () => onAction('backspace')),
              _CalcButton(label: '1/x', isOperator: true, onTap: () => onAction('reciprocal')),
              _CalcButton(label: 'x\u00b2', isOperator: true, onTap: () => onAction('square')),
              _CalcButton(label: '\u00b2\u221ax', isOperator: true, onTap: () => onAction('sqrt')),
              _CalcButton(label: '\u00f7', isOperator: true, onTap: () => onOperator('\u00f7')),
              for (final n in ['7', '8', '9']) _CalcButton(label: n, onTap: () => onNumber(n)),
              _CalcButton(label: '\u00d7', isOperator: true, onTap: () => onOperator('\u00d7')),
              for (final n in ['4', '5', '6']) _CalcButton(label: n, onTap: () => onNumber(n)),
              _CalcButton(label: '\u2212', isOperator: true, onTap: () => onOperator('\u2212')),
              for (final n in ['1', '2', '3']) _CalcButton(label: n, onTap: () => onNumber(n)),
              _CalcButton(label: '+', isOperator: true, onTap: () => onOperator('+')),
              _CalcButton(label: '+/\u2212', onTap: () => onAction('toggle')),
              _CalcButton(label: '0', onTap: () => onNumber('0')),
              _CalcButton(label: '.', onTap: onDecimal),
              _CalcButton(label: '=', isEquals: true, onTap: () => onAction('equals')),
            ],
          ),
        ),
      ],
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.activeTab,
    required this.history,
    required this.memoryHistory,
    required this.onTab,
    required this.onClear,
    required this.onShortcuts,
  });

  final int activeTab;
  final List<HistoryEntry> history;
  final List<HistoryEntry> memoryHistory;
  final ValueChanged<int> onTab;
  final VoidCallback onClear;
  final VoidCallback onShortcuts;

  @override
  Widget build(BuildContext context) {
    final items = activeTab == 0 ? history : memoryHistory;
    final emptyText = activeTab == 0 ? 'No history yet' : 'No memory stored';
    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        children: [
          Row(
            children: [
              _TabButton(label: 'History', active: activeTab == 0, onTap: () => onTab(0)),
              _TabButton(label: 'Memory', active: activeTab == 1, onTap: () => onTab(1)),
              IconButton(onPressed: onShortcuts, icon: const Icon(Icons.more_horiz_rounded)),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: items.isEmpty
                ? Center(child: Text(emptyText, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) => _HistoryTile(entry: items[index]),
                  ),
          ),
          const Divider(height: 1),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(activeTab == 0 ? 'Clear History' : 'Clear Memory'),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(entry.expression, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(entry.result, style: const TextStyle(color: Color(0xFF061326), fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      trailing: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF7A8AA2)),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextButton(
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF006CFF) : const Color(0xFF42516A),
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ShortcutLine extends StatelessWidget {
  const _ShortcutLine(this.keys, this.description);

  final String keys;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF4F9FF),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0x337D97B8)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(keys, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF006CFF), fontWeight: FontWeight.w800)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(description)),
        ],
      ),
    );
  }
}

class _CalcButton extends StatelessWidget {
  const _CalcButton({
    required this.label,
    required this.onTap,
    this.isOperator = false,
    this.isEquals = false,
    this.height,
    this.fontSize,
  });

  final String label;
  final VoidCallback onTap;
  final bool isOperator;
  final bool isEquals;
  final double? height;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isEquals ? 14 : 13),
          gradient: LinearGradient(
            colors: isEquals
                ? const [Color(0xFF38A8FF), Color(0xFF006CFF), Color(0xFF004FD6)]
                : const [Color(0xFFFFFFFF), Color(0xFFF1F7FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0x3D7D97B8)),
          boxShadow: const [
            BoxShadow(color: Color(0x16234678), blurRadius: 18, offset: Offset(0, 8)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(isEquals ? 14 : 13),
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: isEquals
                      ? Colors.white
                      : isOperator
                          ? const Color(0xFF006CFF)
                          : const Color(0xFF061326),
                  fontSize: fontSize ?? (isEquals ? 22 : 18),
                  fontWeight: isOperator || isEquals ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.height, this.padding});

  final Widget child;
  final double? height;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0x3D7D97B8)),
        gradient: const LinearGradient(
          colors: [Color(0xF5FFFFFF), Color(0xC7F3F8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x1F153A76), blurRadius: 48, offset: Offset(0, 18)),
          BoxShadow(color: Color(0x12153A76), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }
}
