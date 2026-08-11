import 'package:flutter/material.dart';

import '../models/stock_candidate.dart';
import '../models/skip_record.dart';
import '../models/skip_record_draft.dart';
import '../repositories/stock_master_repository.dart';
import '../services/stock_search_service.dart';
import '../services/stock_price_service.dart';
import '../theme/app_theme.dart';
import 'skip_record_screen.dart';

class StockSearchScreen extends StatefulWidget {
  const StockSearchScreen({
    super.key,
    this.candidates,
    this.stockMasterRepository = const AssetStockMasterRepository(),
    this.stockSearchService = const StockSearchService(),
    this.stockPriceService,
    this.onSave,
  });

  final List<StockCandidate>? candidates;
  final StockMasterRepository stockMasterRepository;
  final StockSearchService stockSearchService;
  final StockPriceService? stockPriceService;
  final Future<SkipRecord> Function(SkipRecordDraft)? onSave;

  @override
  State<StockSearchScreen> createState() => _StockSearchScreenState();
}

class _StockSearchScreenState extends State<StockSearchScreen> {
  String _query = '';
  late final StockPriceService _stockPriceService;
  List<StockCandidate> _candidates = const [];
  bool _isLoadingMaster = true;
  bool _didFailToLoadMaster = false;

  @override
  void initState() {
    super.initState();
    _stockPriceService = widget.stockPriceService ?? HttpStockPriceService();
    final candidates = widget.candidates;
    if (candidates != null) {
      _candidates = candidates;
      _isLoadingMaster = false;
    } else {
      _loadStockMaster();
    }
  }

  List<StockCandidate> get _filteredCandidates {
    return widget.stockSearchService.search(_candidates, _query);
  }

  Future<void> _loadStockMaster() async {
    try {
      final candidates = await widget.stockMasterRepository.load();
      if (!mounted) return;
      setState(() {
        _candidates = candidates;
        _isLoadingMaster = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _didFailToLoadMaster = true;
        _isLoadingMaster = false;
      });
    }
  }

  void _selectStock(StockCandidate stock) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SkipRecordScreen(
          stock: stock,
          stockPriceService: _stockPriceService,
          onSave: widget.onSave,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _filteredCandidates;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('迷った株を記録'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '銘柄名・銘柄コードで検索',
                  hintStyle: const TextStyle(color: AppColors.mutedText),
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _query.trim().isEmpty ? '銘柄を検索' : '検索結果',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _isLoadingMaster
                    ? const Center(child: CircularProgressIndicator())
                    : _didFailToLoadMaster
                    ? const _SearchMessage(
                        icon: Icons.error_outline_rounded,
                        message: '銘柄情報を読み込めませんでした',
                      )
                    : _query.trim().isEmpty
                    ? const _SearchMessage(
                        icon: Icons.manage_search_rounded,
                        message: '会社名または銘柄コードを入力してください',
                      )
                    : candidates.isEmpty
                    ? const _SearchMessage(
                        icon: Icons.search_off_rounded,
                        message: '該当する銘柄が見つかりませんでした',
                      )
                    : ListView.separated(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: candidates.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final stock = candidates[index];
                          return _StockResultCard(
                            stock: stock,
                            onTap: () => _selectStock(stock),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockResultCard extends StatelessWidget {
  const _StockResultCard({required this.stock, required this.onTap});

  final StockCandidate stock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.outline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.warmAccent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  stock.code.substring(0, 1),
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stock.code,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.mutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stock.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.mutedText, size: 40),
          const SizedBox(height: 10),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }
}
