enum ReportPeriod { daily, weekly, monthly, yearly }

class ReportFilter {
  final DateTime startDate;
  final DateTime endDate;
  final ReportPeriod period;
  final String? categoryFilter;

  ReportFilter({
    required this.startDate,
    required this.endDate,
    required this.period,
    this.categoryFilter,
  });
}

class SalesReportData {
  final DateTime date;
  final double totalSales;
  final int totalTransactions;
  final double averageTransaction;
  final Map<String, double> categoryBreakdown;
  final Map<String, int> itemQuantities;

  SalesReportData({
    required this.date,
    required this.totalSales,
    required this.totalTransactions,
    required this.averageTransaction,
    required this.categoryBreakdown,
    required this.itemQuantities,
  });
}

class ExpenseReportData {
  final DateTime date;
  final double totalExpenses;
  final Map<String, double> categoryBreakdown;
  final int totalExpenseEntries;

  ExpenseReportData({
    required this.date,
    required this.totalExpenses,
    required this.categoryBreakdown,
    required this.totalExpenseEntries,
  });
}

class ProfitLossReportData {
  final DateTime date;
  final double totalRevenue;
  final double totalExpenses;
  final double grossProfit;
  final double netProfit;
  final double profitMargin;

  ProfitLossReportData({
    required this.date,
    required this.totalRevenue,
    required this.totalExpenses,
    required this.grossProfit,
    required this.netProfit,
    required this.profitMargin,
  });
}

class SalesReport {
  final DateTime startDate;
  final DateTime endDate;
  final double totalRevenue;
  final int totalTransactions;
  final double averageTransaction;
  final Map<String, double> categoryBreakdown;
  final List<SalesReportData> dailyData;

  SalesReport({
    required this.startDate,
    required this.endDate,
    required this.totalRevenue,
    required this.totalTransactions,
    required this.averageTransaction,
    required this.categoryBreakdown,
    required this.dailyData,
  });
}

class ExpenseReport {
  final DateTime startDate;
  final DateTime endDate;
  final double totalExpenses;
  final Map<String, double> categoryBreakdown;
  final List<ExpenseReportData> dailyData;

  ExpenseReport({
    required this.startDate,
    required this.endDate,
    required this.totalExpenses,
    required this.categoryBreakdown,
    required this.dailyData,
  });
}

class ProfitLossReport {
  final DateTime startDate;
  final DateTime endDate;
  final double totalRevenue;
  final double totalExpenses;
  final double netProfit;
  final double profitMargin;
  final List<ProfitLossReportData> dailyData;

  ProfitLossReport({
    required this.startDate,
    required this.endDate,
    required this.totalRevenue,
    required this.totalExpenses,
    required this.netProfit,
    required this.profitMargin,
    required this.dailyData,
  });
}

class TopSellingItem {
  final String itemName;
  final int quantitySold;
  final double totalRevenue;

  TopSellingItem({
    required this.itemName,
    required this.quantitySold,
    required this.totalRevenue,
  });
}
