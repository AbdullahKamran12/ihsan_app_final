import 'package:flutter/material.dart';
import 'package:ihsan_app_final/sharedWidgets.dart';
import 'package:ihsan_app_final/screens/moreOptionsScreen.dart';

class ZakatScreen extends StatefulWidget {
  const ZakatScreen({super.key});

  @override
  _ZakatScreenState createState() => _ZakatScreenState();
}

class _ZakatScreenState extends State<ZakatScreen> {
  final TextEditingController savingsController = TextEditingController();
  final TextEditingController goldController = TextEditingController();
  final TextEditingController liabilitiesController = TextEditingController();

  double zakatAmount = 0.0;
  double zakatableWealth = 0.0;
  bool hasCalculated = false;

  // Constants for calculation
  final double nisabInGrams = 612.36;
  final double silverPricePerGram = 0.83;
  final double zakatRate = 0.025; // 2.5%

  void calculateZakat() {
    // Parse input values
    double savings = double.tryParse(savingsController.text) ?? 0.0;
    double goldValue = double.tryParse(goldController.text) ?? 0.0;
    double liabilities = double.tryParse(liabilitiesController.text) ?? 0.0;

    // Calculate total wealth
    double totalWealth = savings + goldValue;

    // Calculate zakatable wealth (assets minus liabilities)
    double zakWealth = totalWealth - liabilities;

    // Calculate nisab threshold
    double nisabValue = nisabInGrams * silverPricePerGram;

    // Calculate zakat if above nisab
    if (zakWealth >= nisabValue) {
      setState(() {
        zakatableWealth = zakWealth;
        zakatAmount = zakWealth * zakatRate;
        hasCalculated = true;
      });
    } else {
      setState(() {
        zakatableWealth = zakWealth;
        zakatAmount = 0.0;
        hasCalculated = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double nisabValue = nisabInGrams * silverPricePerGram;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 105, 170, 190),
      appBar: buildAppBar(
          context, "Zakat Calculator", const MoreOptionsScreen(), null),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Explanation Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "How Zakat Works",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF003366),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "• Zakat is 2.5% of your eligible wealth above the nisab threshold\n"
                        "• The nisab is equivalent to the value of 612.36 grams of silver\n"
                        "• Only pay zakat if your net assets exceed the nisab value",
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Current Nisab Value: £${nisabValue.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Input Section
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Enter Your Financial Information",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF003366),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Savings Input
                    TextField(
                      controller: savingsController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: "Cash & Savings (£)",
                        hintText: "Enter amount in British Pounds (£)",
                        prefixIcon: const Icon(Icons.account_balance_wallet),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Gold Value Input
                    TextField(
                      controller: goldController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: "Gold & Silver Value (£)",
                        hintText:
                            "Enter current market value in British Pounds (£)",
                        prefixIcon: const Icon(Icons.diamond),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        helperText: "The value of all gold and silver you own",
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Liabilities Input
                    TextField(
                      controller: liabilitiesController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: "Liabilities (£)",
                        hintText: "Enter amount in British Pounds (£)",
                        prefixIcon: const Icon(Icons.money_off),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        helperText:
                            "Total debts, loans, and money you owe to others",
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Calculate Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: calculateZakat,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF003366),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          "Calculate Zakat",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Results Section
              if (hasCalculated)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF003366),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Your Zakat Calculation",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Calculation breakdown
                      Text(
                        "Total Assets: £${(double.tryParse(savingsController.text) ?? 0.0) + (double.tryParse(goldController.text) ?? 0.0)}",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Total Liabilities: £${(double.tryParse(liabilitiesController.text) ?? 0.0).toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Net Zakatable Wealth: £${zakatableWealth.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Nisab Threshold: £${nisabValue.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),

                      const Divider(
                          color: Colors.white54, thickness: 1, height: 25),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Your Zakat Amount:",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            "£${zakatAmount.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),

                      if (zakatableWealth < nisabValue)
                        Container(
                          margin: const EdgeInsets.only(top: 15),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info, color: Colors.orange),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Your wealth is below the nisab threshold. Zakat is not obligatory for you at this time.",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Calculation Method Explanation
              if (hasCalculated)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "How Your Zakat Was Calculated",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF003366),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "1. We add up your total assets (cash + gold/silver value)\n"
                          "2. We subtract your total liabilities (debts and loans)\n"
                          "3. If the remaining amount exceeds the nisab threshold, zakat is due\n"
                          "4. Zakat amount = (Total assets - Liabilities) × 2.5%",
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Note: This is a simplified calculation. For complex assets like business inventory, property for investment, or stocks, please consult with a knowledgeable scholar.",
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
