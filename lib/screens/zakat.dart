import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ihsan_app_final/sharedWidgets.dart';
import 'package:ihsan_app_final/screens/moreOptionsScreen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _navy = Color.fromARGB(255, 10, 25, 60);
const Color _navyMid = Color.fromARGB(255, 18, 42, 95);
const Color _navyLight = Color.fromARGB(255, 28, 55, 115);
const Color _gold = Color.fromARGB(255, 212, 175, 95);
const Color _goldLight = Color.fromARGB(255, 252, 243, 210);
const Color _mint = Color.fromARGB(255, 72, 200, 155);
const Color _mintLight = Color.fromARGB(255, 210, 245, 232);
const Color _offWhite = Color.fromARGB(255, 247, 249, 255);
const Color _white = Color.fromARGB(255, 255, 255, 255);
const Color _textDark = Color.fromARGB(255, 15, 30, 65);
const Color _textMid = Color.fromARGB(255, 90, 115, 160);
const Color _border = Color.fromARGB(255, 210, 220, 240);
const Color _red = Color.fromARGB(255, 220, 80, 80);
const Color _redLight = Color.fromARGB(255, 255, 235, 235);

// ── Hanafi Nisab constants ────────────────────────────────────────────────────
// Silver nisab: 612.36 grams (used for cash/mixed assets — Hanafi ruling)
// Gold nisab:   87.48 grams  (used when only gold is held)
const double _silverNisabGrams = 612.36;
const double _goldNisabGrams = 87.48;
const double _zakatRate = 0.025; // 2.5%

class ZakatScreen extends StatefulWidget {
  const ZakatScreen({super.key});
  @override
  State<ZakatScreen> createState() => _ZakatScreenState();
}

class _ZakatScreenState extends State<ZakatScreen> {
  // ── Controllers ──────────────────────────────────────────────────────────
  final _cashController = TextEditingController();
  final _bankController = TextEditingController();
  final _goldGramsController = TextEditingController();
  final _goldPriceController = TextEditingController();
  final _silverGramsController = TextEditingController();
  final _silverPriceController = TextEditingController();
  final _stocksController = TextEditingController();
  final _businessController = TextEditingController();
  final _receivablesController = TextEditingController();
  final _pensionController = TextEditingController();
  final _otherAssetsController = TextEditingController();

  // Deductions (Hanafi: only immediate debts due within the year)
  final _immediateDebtsController = TextEditingController();
  final _otherDeductionsController = TextEditingController();

  // Silver & gold price per gram — user can adjust
  final _silverPricePerGramController =
      TextEditingController(text: '0.85'); // approximate £/g
  final _goldPricePerGramController =
      TextEditingController(text: '65.00'); // approximate £/g

  bool _hawlConfirmed = false;
  bool _hasCalculated = false;
  bool _showBreakdown = false;

  // Results
  double _totalAssets = 0;
  double _totalDeductions = 0;
  double _netWealth = 0;
  double _silverNisabValue = 0;
  double _zakatDue = 0;
  bool _aboveNisab = false;

  // Computed gold value shown inline
  double get _goldValue {
    final grams = double.tryParse(_goldGramsController.text) ?? 0;
    final price = double.tryParse(_goldPricePerGramController.text) ?? 0;
    return grams * price;
  }

  double get _silverValue {
    final grams = double.tryParse(_silverGramsController.text) ?? 0;
    final price = double.tryParse(_silverPriceController.text) ?? 0;
    return grams * price;
  }

  void _calculate() {
    final silverPricePerGram =
        double.tryParse(_silverPricePerGramController.text) ?? 0.85;

    // ── Assets ──────────────────────────────────────────────────────────────
    final cash = double.tryParse(_cashController.text) ?? 0;
    final bank = double.tryParse(_bankController.text) ?? 0;
    final goldGrams = double.tryParse(_goldGramsController.text) ?? 0;
    final goldPricePerGram =
        double.tryParse(_goldPricePerGramController.text) ?? 0;
    final goldVal = goldGrams * goldPricePerGram;
    final silverVal = _silverValue;
    final stocks = double.tryParse(_stocksController.text) ?? 0;
    final business = double.tryParse(_businessController.text) ?? 0;
    // Hanafi: receivables that are likely to be repaid (strong debts)
    final receivables = double.tryParse(_receivablesController.text) ?? 0;
    // Hanafi: only accessible pension funds (not locked)
    final pension = double.tryParse(_pensionController.text) ?? 0;
    final other = double.tryParse(_otherAssetsController.text) ?? 0;

    final totalAssets = cash +
        bank +
        goldVal +
        silverVal +
        stocks +
        business +
        receivables +
        pension +
        other;

    // ── Deductions (Hanafi: only immediate debts due within the year) ───────
    final immediateDebts = double.tryParse(_immediateDebtsController.text) ?? 0;
    final otherDeductions =
        double.tryParse(_otherDeductionsController.text) ?? 0;
    final totalDeductions = immediateDebts + otherDeductions;

    final netWealth = totalAssets - totalDeductions;

    // ── Nisab (silver — Hanafi default for mixed/cash wealth) ───────────────
    final silverNisabValue = _silverNisabGrams * silverPricePerGram;

    final aboveNisab = netWealth >= silverNisabValue;
    final zakatDue = aboveNisab ? netWealth * _zakatRate : 0.0;

    setState(() {
      _totalAssets = totalAssets;
      _totalDeductions = totalDeductions;
      _netWealth = netWealth;
      _silverNisabValue = silverNisabValue;
      _aboveNisab = aboveNisab;
      _zakatDue = zakatDue;
      _hasCalculated = true;
      _showBreakdown = true;
    });
  }

  void _reset() {
    for (final c in [
      _cashController,
      _bankController,
      _goldGramsController,
      _silverGramsController,
      _silverPriceController,
      _stocksController,
      _businessController,
      _receivablesController,
      _pensionController,
      _otherAssetsController,
      _immediateDebtsController,
      _otherDeductionsController,
    ]) {
      c.clear();
    }
    _goldPricePerGramController.text = '65.00';
    _silverPricePerGramController.text = '0.85';
    setState(() {
      _hawlConfirmed = false;
      _hasCalculated = false;
      _showBreakdown = false;
    });
  }

  @override
  void dispose() {
    for (final c in [
      _cashController,
      _bankController,
      _goldGramsController,
      _goldPricePerGramController,
      _silverGramsController,
      _silverPriceController,
      _stocksController,
      _businessController,
      _receivablesController,
      _pensionController,
      _otherAssetsController,
      _immediateDebtsController,
      _otherDeductionsController,
      _silverPricePerGramController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      appBar: buildAppBar(
          context, 'Zakat Calculator', const MoreOptionsScreen(), null),
      body: Container(
        color: _offWhite,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const QurbaniBanner(),
            // ── Info card ──────────────────────────────────────────────────
            _infoCard(),
            const SizedBox(height: 16),

            // ── Nisab price inputs ─────────────────────────────────────────
            _sectionHeader('Metal Prices', Icons.show_chart_rounded),
            const SizedBox(height: 8),
            _metalPricesCard(),
            const SizedBox(height: 16),

            // ── Assets ────────────────────────────────────────────────────
            _sectionHeader(
                'Zakatable Assets', Icons.account_balance_wallet_outlined),
            const SizedBox(height: 8),
            _assetsCard(),
            const SizedBox(height: 16),

            // ── Deductions ────────────────────────────────────────────────
            _sectionHeader('Deductions', Icons.remove_circle_outline_rounded),
            const SizedBox(height: 8),
            _deductionsCard(),
            const SizedBox(height: 16),

            // ── Hawl confirmation ─────────────────────────────────────────
            _hawlCard(),
            const SizedBox(height: 20),

            // ── Calculate button ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _hawlConfirmed ? _calculate : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _navy,
                  disabledBackgroundColor: _border,
                  disabledForegroundColor: _textMid,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Calculate Zakat',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),

            const SizedBox(height: 16),

            // ── Results ───────────────────────────────────────────────────
            if (_hasCalculated) ...[
              _resultsCard(),
              const SizedBox(height: 16),
              if (_showBreakdown) _breakdownCard(),
              const SizedBox(height: 16),
              _scholarNote(),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh_rounded,
                    size: 16, color: _textMid),
                label: const Text('Reset Calculator',
                    style: TextStyle(color: _textMid, fontSize: 13)),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────
  Widget _sectionHeader(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 16, color: _textMid),
      const SizedBox(width: 7),
      Text(title.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: _textMid)),
    ]);
  }

  // ── Info card ──────────────────────────────────────────────────────────────
  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _navyMid,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withOpacity(0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: _gold),
          const SizedBox(width: 8),
          const Text('Hanafi Fiqh — Zakat al-Mal',
              style: TextStyle(
                  color: _gold, fontWeight: FontWeight.w700, fontSize: 14)),
        ]),
        const SizedBox(height: 10),
        _infoRow(
            'Nisab (Silver)', '612.36 g silver — used for cash & mixed wealth'),
        _infoRow('Nisab (Gold)', '87.48 g gold — used when only gold is held'),
        _infoRow('Rate', '2.5% of net zakatable wealth'),
        _infoRow('Hawl', 'Wealth must be held for one complete lunar year'),
        _infoRow('Debts', 'Only immediate debts (due this year) are deducted'),
      ]),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('• ',
            style: TextStyle(color: _gold, fontWeight: FontWeight.w700)),
        Text('$label: ',
            style: const TextStyle(
                color: _gold, fontWeight: FontWeight.w600, fontSize: 12)),
        Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white70, fontSize: 12))),
      ]),
    );
  }

  // ── Metal prices card ──────────────────────────────────────────────────────
  Widget _metalPricesCard() {
    return _card(
      child: Column(children: [
        _fieldRow(
          label: 'Silver price per gram (£)',
          hint: 'e.g. 0.85',
          controller: _silverPricePerGramController,
          icon: Icons.monetization_on_outlined,
          tooltip:
              'Used to calculate the silver nisab threshold (612.36g × price)',
        ),
        const SizedBox(height: 12),
        _fieldRow(
          label: 'Gold price per gram (£)',
          hint: 'e.g. 65.00',
          controller: _goldPricePerGramController,
          icon: Icons.circle_outlined,
          tooltip: 'Used to calculate the value of your gold holdings',
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: _goldLight, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 13, color: _textMid),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Check a live spot price site (e.g. goldprice.org) for today\'s UK prices.',
                style: TextStyle(fontSize: 11, color: _textMid),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Assets card ────────────────────────────────────────────────────────────
  Widget _assetsCard() {
    return _card(
      child: Column(children: [
        _fieldRow(
          label: 'Cash in hand (£)',
          hint: '0.00',
          controller: _cashController,
          icon: Icons.payments_outlined,
          tooltip: 'Physical cash you currently hold',
        ),
        const Divider(height: 24, color: _border),
        _fieldRow(
          label: 'Bank savings & current accounts (£)',
          hint: '0.00',
          controller: _bankController,
          icon: Icons.account_balance_outlined,
          tooltip:
              'All balances across current, savings and ISA accounts you have access to',
        ),
        const Divider(height: 24, color: _border),

        // Gold — grams input + auto-calculated value
        _goldSectionField(),
        const Divider(height: 24, color: _border),

        // Silver — grams input + auto-calculated value
        _silverSectionField(),
        const Divider(height: 24, color: _border),

        _fieldRow(
          label: 'Stocks & shares (£)',
          hint: '0.00',
          controller: _stocksController,
          icon: Icons.trending_up_rounded,
          tooltip:
              'Hanafi position: include the zakatable portion of shares (typically the net asset value per share × your shares). For listed equity funds, apply the zakatable portion ratio provided by your fund or use 25% as a conservative estimate if unknown.',
        ),
        const Divider(height: 24, color: _border),

        _fieldRow(
          label: 'Business inventory (£)',
          hint: '0.00',
          controller: _businessController,
          icon: Icons.storefront_outlined,
          tooltip:
              'Trading stock and goods held for sale at their current market value. Fixed assets (machinery, property used in the business) are NOT zakatable.',
        ),
        const Divider(height: 24, color: _border),

        _fieldRow(
          label: 'Money owed to you — strong receivables (£)',
          hint: '0.00',
          controller: _receivablesController,
          icon: Icons.handshake_outlined,
          tooltip:
              'Hanafi ruling: include money others owe you that you genuinely expect to receive. Doubtful or written-off debts are excluded.',
        ),
        const Divider(height: 24, color: _border),

        _fieldRow(
          label: 'Accessible pension funds (£)',
          hint: '0.00',
          controller: _pensionController,
          icon: Icons.savings_outlined,
          tooltip:
              'Hanafi scholars differ. Include only the portion you can currently withdraw without penalty. Future/locked pension pots are excluded by most Hanafi scholars.',
        ),
        const Divider(height: 24, color: _border),

        _fieldRow(
          label: 'Other zakatable assets (£)',
          hint: '0.00',
          controller: _otherAssetsController,
          icon: Icons.add_circle_outline_rounded,
          tooltip:
              'Any other liquid or near-liquid assets not listed above (e.g. crypto at current value, rental income held, prize bonds at face value).',
        ),
      ]),
    );
  }

  Widget _goldSectionField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: _goldLight, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.circle, size: 14, color: _gold),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Gold you own (grams)',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textDark)),
            Text(
                'Hanafi: personal jewellery worn regularly is debated — safer to include',
                style: TextStyle(fontSize: 10, color: _textMid)),
          ]),
        ),
        GestureDetector(
          onTap: () => _showTooltipDialog('Gold (Hanafi)',
              'In the Hanafi madhab, gold owned for personal use (regularly worn jewellery) is still subject to zakat according to the dominant position. This differs from the Shafi\'i and Hanbali views. To be safe, include all gold you own.\n\nGold nisab = 87.48g — relevant only if you hold gold alone with no cash. If you hold both, use the silver nisab for the combined total.'),
          child:
              const Icon(Icons.help_outline_rounded, size: 16, color: _textMid),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _goldGramsController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
            ],
            onChanged: (_) => setState(() {}),
            decoration: _inputDecoration('Weight in grams', '0.0'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: _goldLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _gold.withOpacity(0.4)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Value',
                  style: TextStyle(fontSize: 10, color: _textMid)),
              Text('£${_goldValue.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _textDark)),
            ]),
          ),
        ),
      ]),
    ]);
  }

  Widget _silverSectionField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: const Color.fromARGB(255, 235, 235, 245),
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.circle, size: 14, color: _textMid),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Silver you own (grams)',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textDark)),
            Text('Include all silver items, coins, and silverware',
                style: TextStyle(fontSize: 10, color: _textMid)),
          ]),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _silverGramsController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
            ],
            onChanged: (_) => setState(() {}),
            decoration: _inputDecoration('Weight in grams', '0.0'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 235, 235, 245),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _textMid.withOpacity(0.3)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Value',
                  style: TextStyle(fontSize: 10, color: _textMid)),
              Text('£${_silverValue.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _textDark)),
            ]),
          ),
        ),
      ]),
    ]);
  }

  // ── Deductions card ────────────────────────────────────────────────────────
  Widget _deductionsCard() {
    return _card(
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: _redLight, borderRadius: BorderRadius.circular(10)),
          child: const Row(children: [
            Icon(Icons.warning_amber_rounded, size: 14, color: _red),
            SizedBox(width: 7),
            Expanded(
              child: Text(
                'Hanafi ruling: only debts due within the next lunar year are deductible. '
                'Long-term liabilities (mortgages, multi-year loans) are NOT fully deducted — '
                'only this year\'s repayment instalment.',
                style: TextStyle(fontSize: 11, color: _red, height: 1.4),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        _fieldRow(
          label: 'Immediate debts due this year (£)',
          hint: '0.00',
          controller: _immediateDebtsController,
          icon: Icons.money_off_rounded,
          tooltip:
              'Debts that must be paid within the lunar year: rent arrears, outstanding bills, short-term loans, this year\'s mortgage instalment (not the full balance).',
        ),
        const Divider(height: 24, color: _border),
        _fieldRow(
          label: 'Other immediate obligations (£)',
          hint: '0.00',
          controller: _otherDeductionsController,
          icon: Icons.remove_circle_outline_rounded,
          tooltip:
              'e.g. money you owe to others personally that is demanded, unpaid employee wages, zakah already paid this year.',
        ),
      ]),
    );
  }

  // ── Hawl confirmation card ─────────────────────────────────────────────────
  Widget _hawlCard() {
    return GestureDetector(
      onTap: () => setState(() => _hawlConfirmed = !_hawlConfirmed),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _hawlConfirmed ? _mintLight : _white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hawlConfirmed ? _mint : _border,
            width: _hawlConfirmed ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
                color: _navy.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _hawlConfirmed ? _mint : _white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: _hawlConfirmed ? _mint : _border, width: 1.5),
            ),
            child: _hawlConfirmed
                ? const Icon(Icons.check_rounded, size: 16, color: _white)
                : null,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('I confirm Hawl (one lunar year) has passed',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _textDark)),
              SizedBox(height: 2),
              Text(
                  'My wealth has been above the nisab for a complete lunar year (354 days)',
                  style: TextStyle(fontSize: 11, color: _textMid)),
            ]),
          ),
          GestureDetector(
            onTap: () => _showTooltipDialog('Hawl',
                'Hawl means the completion of one full lunar year (approximately 354 days) on your zakatable wealth.\n\nYour wealth must have stayed at or above the nisab threshold throughout the entire year. If your wealth fell below the nisab at any point during the year, the hawl resets from the point it reaches nisab again.\n\nIf you are unsure of your exact hawl date, many scholars recommend taking a consistent date each year (e.g. 1st Ramadan) and checking your wealth on that date.'),
            child: const Icon(Icons.help_outline_rounded,
                size: 16, color: _textMid),
          ),
        ]),
      ),
    );
  }

  // ── Results card ───────────────────────────────────────────────────────────
  Widget _resultsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _aboveNisab ? _navyMid : _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _aboveNisab ? _gold.withOpacity(0.5) : _border,
          width: 1.5,
        ),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _aboveNisab
                    ? _gold.withOpacity(0.2)
                    : _border.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(
                _aboveNisab
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                size: 20,
                color: _aboveNisab ? _gold : _textMid),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _aboveNisab
                  ? 'Zakat is obligatory'
                  : 'Below nisab — Zakat not obligatory',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _aboveNisab ? _gold : _textDark),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _resultRow(
            'Total Assets', '£${_totalAssets.toStringAsFixed(2)}', _aboveNisab),
        _resultRow('Total Deductions',
            '− £${_totalDeductions.toStringAsFixed(2)}', _aboveNisab),
        _resultRow('Net Zakatable Wealth', '£${_netWealth.toStringAsFixed(2)}',
            _aboveNisab,
            bold: true),
        _resultRow('Silver Nisab Threshold',
            '£${_silverNisabValue.toStringAsFixed(2)}', _aboveNisab),
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: _aboveNisab
                ? _gold.withOpacity(0.15)
                : _border.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _aboveNisab ? _gold.withOpacity(0.5) : _border),
          ),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Zakat Due (2.5%)',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _aboveNisab ? _gold : _textMid)),
            Text('£${_zakatDue.toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _aboveNisab ? _gold : _textMid)),
          ]),
        ),
      ]),
    );
  }

  Widget _resultRow(String label, String value, bool light,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: light ? Colors.white70 : _textMid,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: light ? Colors.white : _textDark)),
      ]),
    );
  }

  // ── Breakdown card ─────────────────────────────────────────────────────────
  Widget _breakdownCard() {
    final goldGrams = double.tryParse(_goldGramsController.text) ?? 0;
    final goldPricePerGram =
        double.tryParse(_goldPricePerGramController.text) ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.receipt_long_outlined, size: 16, color: _textMid),
          const SizedBox(width: 7),
          const Text('Full Breakdown',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _textDark)),
        ]),
        const SizedBox(height: 12),
        _breakRow('Cash in hand', double.tryParse(_cashController.text) ?? 0),
        _breakRow('Bank savings', double.tryParse(_bankController.text) ?? 0),
        _breakRow(
            'Gold (${goldGrams.toStringAsFixed(1)}g × £${goldPricePerGram.toStringAsFixed(2)})',
            _goldValue),
        _breakRow(
            'Silver (${(double.tryParse(_silverGramsController.text) ?? 0).toStringAsFixed(1)}g)',
            _silverValue),
        _breakRow(
            'Stocks & shares', double.tryParse(_stocksController.text) ?? 0),
        _breakRow('Business inventory',
            double.tryParse(_businessController.text) ?? 0),
        _breakRow(
            'Receivables', double.tryParse(_receivablesController.text) ?? 0),
        _breakRow('Pension (accessible)',
            double.tryParse(_pensionController.text) ?? 0),
        _breakRow(
            'Other assets', double.tryParse(_otherAssetsController.text) ?? 0),
        const Divider(height: 20, color: _border),
        _breakRow('Total Assets', _totalAssets, bold: true),
        _breakRow('Immediate debts',
            -(double.tryParse(_immediateDebtsController.text) ?? 0),
            red: true),
        _breakRow('Other deductions',
            -(double.tryParse(_otherDeductionsController.text) ?? 0),
            red: true),
        const Divider(height: 20, color: _border),
        _breakRow('Net Zakatable Wealth', _netWealth, bold: true),
        _breakRow('× 2.5% Zakat Rate', _zakatDue, bold: true, gold: true),
      ]),
    );
  }

  Widget _breakRow(String label, double value,
      {bool bold = false, bool red = false, bool gold = false}) {
    if (value == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: red ? _red : _textMid,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
        Text('${value < 0 ? '−' : ''}£${value.abs().toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: gold
                    ? _gold
                    : red
                        ? _red
                        : _textDark)),
      ]),
    );
  }

  // ── Scholar note ───────────────────────────────────────────────────────────
  Widget _scholarNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: _goldLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _gold.withOpacity(0.4))),
      child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.menu_book_rounded, size: 14, color: _textMid),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'This calculator follows the Hanafi madhab. For complex situations — '
            'business partnerships, agricultural produce, livestock, cryptocurrency, '
            'or unusual financial instruments — please consult a qualified Islamic scholar or mufti.',
            style: TextStyle(fontSize: 11, color: _textMid, height: 1.5),
          ),
        ),
      ]),
    );
  }

  // ── Shared field row ───────────────────────────────────────────────────────
  Widget _fieldRow({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    String? tooltip,
  }) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
            color: _offWhite, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: _textMid),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textDark))),
            if (tooltip != null)
              GestureDetector(
                onTap: () {
                  final shortLabel = label.split('(')[0].trim();
                  _showTooltipDialog(shortLabel, tooltip);
                },
                child: const Icon(Icons.help_outline_rounded,
                    size: 15, color: _textMid),
              ),
          ]),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
            ],
            decoration: _inputDecoration(hint, hint),
          ),
        ]),
      ),
    ]);
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _textMid, fontSize: 13),
      filled: true,
      fillColor: _offWhite,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _gold, width: 1.5),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
              color: _navy.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: child,
    );
  }

  void _showTooltipDialog(String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _offWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(
                color: _textDark, fontWeight: FontWeight.w700, fontSize: 15)),
        content: Text(body,
            style: const TextStyle(color: _textMid, fontSize: 13, height: 1.6)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: _gold,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
