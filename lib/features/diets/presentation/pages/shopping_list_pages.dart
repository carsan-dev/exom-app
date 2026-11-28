import 'dart:async';

import 'package:exom_app/core/formatters/figure_format.dart';
import 'package:exom_app/core/navigation/page_aware_bottom_sheet.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_choice_chips.dart';
import 'package:exom_app/core/widgets/exom_index_number.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/core/widgets/exom_segmented_control.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/entities/diet_period_entity.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_export.dart';
import 'package:exom_app/features/diets/domain/utils/diet_export_period_utils.dart';
import 'package:exom_app/features/diets/presentation/widgets/weekly_shopping_list_flow.dart';
import 'package:exom_app/features/diets/services/ingredient_unit_formatter.dart';
import 'package:exom_app/features/diets/services/shopping_list_checks_store.dart';
import 'package:exom_app/features/diets/services/weekly_diet_pdf_service.dart';
import 'package:exom_app/features/diets/services/weekly_shopping_list_builder.dart';
import 'package:exom_app/features/home/presentation/widgets/home_headline.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

/// L5-E8 «Lista de la compra» (sketch e-migradas.html, frames f-compra and
/// f-compra-lista; L5-D16 and L5-D25): the choice of alternatives and the
/// list with one mark per product are two pushed screens (they were a bottom
/// sheet and a PDF straight away). The products come from the same
/// [WeeklyShoppingListBuilder] as the PDF, which «Compartir lista» still
/// builds and offers to print or share.

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

/// «Semana del 16 de noviembre al 22 de noviembre» or «Noviembre de 2026».
String shoppingListPeriodLabel(
  AppLocalizations l10n,
  String locale,
  DietPeriodEntity period, {
  required bool calendarMonth,
}) {
  if (calendarMonth) {
    return _capitalize(DateFormat.yMMMM(locale).format(period.start));
  }
  final day = DateFormat.MMMMd(locale);
  return l10n.shoppingListWeekRange(
    day.format(period.start),
    day.format(period.end),
  );
}

/// Secondary line under the screen title (sketch `.sec`).
TextStyle _secondaryStyle(BuildContext context) => TextStyle(
  fontFamily: AppTheme.bodyFontFamily,
  fontSize: 14,
  height: 1.35,
  color: context.exomPalette.textSecondary,
);

/// Bar with «Volver» only (sketch `.hdr-push`), the screen title as the first
/// line of the body, the content scrolling and the pinned [footer].
class _ShoppingListScaffold extends StatelessWidget {
  const _ShoppingListScaffold({
    super.key,
    required this.subtitle,
    required this.children,
    required this.footer,
  });

  final String subtitle;
  final List<Widget> children;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ExomStaticBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: Icon(ExomIcons.back, color: palette.textPrimary),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: ExomSpacing.lg),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: HomeTitle(l10n.weeklyExportShoppingList),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(subtitle, style: _secondaryStyle(context)),
            ),
            ...children,
          ],
        ),
        bottomNavigationBar: ExomPinnedFooter(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
          child: footer,
        ),
      ),
    );
  }
}

/// Screen «Elige tus alternativas» (frame f-compra): one numbered question
/// per meal with alternatives, labelled with its weekday, date and meal
/// (L4-I25b: a month repeats weekdays), answered with a segmented control
/// (two or three options) or chips (more). «Generar lista» pushes
/// [ShoppingListPage] with the choice; back returns here.
class ShoppingListSetupPage extends StatefulWidget {
  const ShoppingListSetupPage({
    super.key,
    required this.period,
    required this.calendarMonth,
    required this.mealTypes,
  });

  static const Key pageKey = Key('shopping-list-setup');

  final DietPeriodEntity period;
  final bool calendarMonth;

  /// Upper-case meal type to its label.
  final Map<String, String> mealTypes;

  @override
  State<ShoppingListSetupPage> createState() => _ShoppingListSetupPageState();
}

class _ShoppingListSetupPageState extends State<ShoppingListSetupPage> {
  final Map<String, String> _selectedIds = {};

  Iterable<(DietPeriodDayEntity, MealEntity)> get _questions sync* {
    for (final day in widget.period.days) {
      for (final meal in day.diet?.meals ?? const <MealEntity>[]) {
        if (meal.variants.isNotEmpty) yield (day, meal);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    for (final (day, meal) in _questions) {
      _selectedIds[WeeklyMealSelection.selectionKey(day.date, meal.id)] =
          meal.id;
    }
  }

  List<WeeklyMealSelection> _result() => [
    for (final (day, meal) in _questions)
      WeeklyMealSelection(
        date: day.date,
        parentMealId: meal.id,
        selectedMealId:
            _selectedIds[WeeklyMealSelection.selectionKey(day.date, meal.id)] ??
            meal.id,
      ),
  ];

  bool _opening = false;

  Future<void> _generate() async {
    if (_opening) return;
    _opening = true;
    try {
      await pushShoppingListRoute<void>(
        context,
        (_) => ShoppingListPage(
          period: widget.period,
          calendarMonth: widget.calendarMonth,
          selections: _result(),
        ),
      );
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final dayFormat = DateFormat('EEEE d', locale);
    final questions = _questions.toList();
    final count = questions.length;
    return _ShoppingListScaffold(
      key: ShoppingListSetupPage.pageKey,
      subtitle: shoppingListPeriodLabel(
        l10n,
        locale,
        widget.period,
        calendarMonth: widget.calendarMonth,
      ),
      footer: ExomPrimaryButton(
        key: const Key('shopping-list-generate'),
        label: l10n.weeklyGenerateShoppingList,
        trailingIcon: ExomIcons.forward,
        onPressed: _generate,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: ExomTwoLineHeadline(
            first: l10n.shoppingListSetupFirst,
            second: l10n.shoppingListSetupSecond,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExomKicker(l10n.weeklyVariantSelectorTitle),
              const SizedBox(height: ExomSpacing.md),
              _HeroCount(
                value: formatFigure(context, count),
                noun: l10n.shoppingListMealsWithOptions(count),
                foot: l10n.shoppingListMealsWithOptionsFoot,
              ),
            ],
          ),
        ),
        const SizedBox(height: ExomSpacing.md),
        for (var i = 0; i < questions.length; i++)
          _question(
            context,
            n: i + 1,
            day: questions[i].$1,
            meal: questions[i].$2,
            label: l10n.shoppingListQuestion(
              _capitalize(dayFormat.format(questions[i].$1.date)),
              widget.mealTypes[questions[i].$2.type.toUpperCase()] ??
                  questions[i].$2.type,
            ),
            last: i == questions.length - 1,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Text(
            l10n.shoppingListSetupNote,
            style: _secondaryStyle(context),
          ),
        ),
      ],
    );
  }

  Widget _question(
    BuildContext context, {
    required int n,
    required DietPeriodDayEntity day,
    required MealEntity meal,
    required String label,
    required bool last,
  }) {
    final l10n = AppLocalizations.of(context);
    final key = WeeklyMealSelection.selectionKey(day.date, meal.id);
    final options = [meal.id, ...meal.variants.map((variant) => variant.id)];
    String labelOf(String id) => id == meal.id
        ? l10n.weeklyVariantMain
        : meal.variants.firstWhere((variant) => variant.id == id).name;
    void onChanged(String id) => setState(() => _selectedIds[key] = id);
    final selected = _selectedIds[key] ?? meal.id;
    return _NumberedQuestion(
      n: n,
      label: label,
      bottomRule: last,
      child: options.length <= 3
          ? ExomSegmentedControl<String>(
              options: options,
              selected: selected,
              labelOf: labelOf,
              onChanged: onChanged,
            )
          : ExomChoiceChips<String>(
              options: options,
              selected: selected,
              labelOf: labelOf,
              onSelected: onChanged,
            ),
    );
  }
}

/// Numbered question (sketch `.x-q`, `.x-q-l`): a hairline on top, «01» and
/// the label, then the control.
class _NumberedQuestion extends StatelessWidget {
  const _NumberedQuestion({
    required this.n,
    required this.label,
    required this.child,
    this.bottomRule = false,
  });

  final int n;
  final String label;
  final Widget child;
  final bool bottomRule;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final rule = BorderSide(color: palette.borderSoft, width: ExomRule.hairline);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: rule, bottom: bottomRule ? rule : BorderSide.none),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  ExcludeSemantics(child: ExomIndexNumber(n)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ExomSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

/// Protagonist count at 96 with its noun and a foot line beside it (sketch
/// `.x-hero`, `.x-hero-d`, `.x-hero-f`).
class _HeroCount extends StatelessWidget {
  const _HeroCount({
    required this.value,
    required this.noun,
    required this.foot,
  });

  final String value;
  final String noun;
  final String foot;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return ExomNumeral(
      value: value,
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            noun.toUpperCase(),
            semanticsLabel: noun,
            style: ExomType.headline2Section.copyWith(
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: ExomSpacing.xs),
          Text(foot, style: _secondaryStyle(context)),
        ],
      ),
    );
  }
}

/// Screen «Tu lista. / Esta semana.» (frame f-compra-lista): the products of
/// the list, each with a mark, and «Compartir lista», which builds the same
/// PDF as before and offers the same print / share sheet.
///
/// The marks are kept on this device by [ShoppingListChecksStore] for the
/// owner captured when the screen opens, the period and the chosen
/// alternatives (L5-D25). A write is never attributed to another session.
class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({
    super.key,
    required this.period,
    required this.calendarMonth,
    required this.selections,
    this.store,
    this.now,
  });

  static const Key pageKey = Key('shopping-list-result');

  final DietPeriodEntity period;
  final bool calendarMonth;
  final List<WeeklyMealSelection> selections;

  /// Where the marks are kept; by default the app's preferences store, and
  /// none when the app has no [LocalStorage] (the marks then stay on screen).
  final ShoppingListChecksStore? store;

  /// Clock that tells whether [period] is the current week; by default
  /// [DateTime.now].
  final DateTime Function()? now;

  /// Key of the row of the product with [productId], for tests.
  static Key itemKey(String productId) =>
      ValueKey<String>('shopping-item:$productId');

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  late final ShoppingListChecksStore? _store =
      widget.store ?? ShoppingListChecksStore.fromLocator();
  late final ShoppingListScope _scope = ShoppingListScope(
    periodStart: widget.period.start,
    kind: widget.calendarMonth
        ? ShoppingListPeriodKind.month
        : ShoppingListPeriodKind.week,
    selectionSignature: ShoppingListChecksStore.selectionSignature(
      widget.selections,
    ),
  );
  ShoppingListOwner? _owner;
  String? _locale;

  /// Whether today falls in [ShoppingListPage.period] (days, both ends
  /// included): only then the headline says «Esta semana.» (r3).
  bool _isCurrentWeek() {
    final now = (widget.now ?? DateTime.now)();
    final today = DateTime(now.year, now.month, now.day);
    final start = widget.period.start;
    final end = widget.period.end;
    return !today.isBefore(DateTime(start.year, start.month, start.day)) &&
        !today.isAfter(DateTime(end.year, end.month, end.day));
  }
  List<ShoppingListItem> _items = const [];
  final Set<String> _checked = {};
  Future<void> _writes = Future.value();
  bool _sharing = false;
  bool _shareFailed = false;

  @override
  void initState() {
    super.initState();
    // The owner of this screen: a later session change never gets its marks.
    _owner = _store?.currentOwner();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).toString();
    if (locale == _locale) return;
    final first = _locale == null;
    _locale = locale;
    _items = const WeeklyShoppingListBuilder().build(
      week: widget.period,
      selections: widget.selections,
      locale: locale,
    );
    if (first) {
      final owner = _owner;
      final store = _store;
      if (owner != null && store != null) {
        final ids = _items.map(ShoppingListChecksStore.productId).toSet();
        _checked.addAll(store.read(owner, _scope).where(ids.contains));
      }
    }
  }

  void _toggle(String productId) {
    setState(() {
      if (!_checked.remove(productId)) _checked.add(productId);
    });
    final owner = _owner;
    final store = _store;
    if (owner == null || store == null) return;
    final snapshot = Set<String>.of(_checked);
    // In order: the last mark tapped is the one kept.
    _writes = _writes.then((_) => store.write(owner, _scope, snapshot));
  }

  Future<void> _share() async {
    if (_sharing) return;
    final l10n = AppLocalizations.of(context);
    final locale = _locale ?? Localizations.localeOf(context).toString();
    setState(() {
      _sharing = true;
      _shareFailed = false;
    });
    try {
      final bytes = await GetIt.I<WeeklyDietPdfService>().buildShoppingList(
        week: widget.period,
        items: _items,
        locale: locale,
        labels: WeeklyShoppingListPdfLabels(
          title: widget.calendarMonth
              ? l10n.monthlyShoppingListPdfTitle
              : l10n.weeklyShoppingListPdfTitle,
          empty: widget.calendarMonth
              ? l10n.monthlyShoppingListEmpty
              : l10n.weeklyShoppingListEmpty,
        ),
      );
      if (!mounted) return;
      await printOrSharePdf(
        context,
        bytes: bytes,
        filename: dietExportFilename(
          shoppingList: true,
          start: widget.period.start,
          end: widget.period.end,
          calendarMonth: widget.calendarMonth,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _shareFailed = true);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final count = _items.length;
    final checked = _items
        .where((item) => _checked.contains(ShoppingListChecksStore.productId(item)))
        .length;
    final formatter = IngredientUnitFormatter(locale: locale);
    return _ShoppingListScaffold(
      key: ShoppingListPage.pageKey,
      subtitle: shoppingListPeriodLabel(
        l10n,
        locale,
        widget.period,
        calendarMonth: widget.calendarMonth,
      ),
      footer: ExomPrimaryButton(
        key: const Key('shopping-list-share'),
        label: l10n.shoppingListShare,
        trailingIcon: ExomIcons.forward,
        busy: _sharing,
        onPressed: _share,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: ExomTwoLineHeadline(
            first: l10n.shoppingListResultFirst,
            second: widget.calendarMonth
                ? l10n.shoppingListResultSecondMonth
                : _isCurrentWeek()
                ? l10n.shoppingListResultSecondWeek
                : l10n.shoppingListResultSecondWeekOf(
                    DateFormat.MMMd(locale).format(widget.period.start),
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: _HeroCount(
            value: formatFigure(context, count),
            noun: l10n.shoppingListProducts(count),
            foot: l10n.shoppingListCheckedCount(checked),
          ),
        ),
        if (_shareFailed)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: ExomInlineMessage(
              kind: ExomMessageKind.error,
              title: l10n.weeklyDietExportError,
            ),
          ),
        const SizedBox(height: ExomSpacing.md),
        if (_items.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              widget.calendarMonth
                  ? l10n.monthlyShoppingListEmpty
                  : l10n.weeklyShoppingListEmpty,
              style: _secondaryStyle(context),
            ),
          )
        else
          for (var i = 0; i < _items.length; i++)
            _ProductRow(
              key: ShoppingListPage.itemKey(
                ShoppingListChecksStore.productId(_items[i]),
              ),
              name: _items[i].name,
              amount: formatter.shoppingAmount(
                quantityValue: _items[i].quantity,
                unitCode: _items[i].unit,
                gramsEquivalent: _items[i].gramsEquivalent,
                toTaste: _items[i].toTaste,
              ),
              checked: _checked.contains(
                ShoppingListChecksStore.productId(_items[i]),
              ),
              bottomRule: i == _items.length - 1,
              onTap: () =>
                  _toggle(ShoppingListChecksStore.productId(_items[i])),
            ),
      ],
    );
  }
}

/// Flat product row (sketch `.rows .r`): the 48 dp mark on the left (empty
/// outline, or a heavier outline with a check in the data colour once bought,
/// never a lime fill), the name and the amount on the right. The whole row
/// toggles the mark and reads as one checkbox-like node.
class _ProductRow extends StatelessWidget {
  const _ProductRow({
    super.key,
    required this.name,
    required this.amount,
    required this.checked,
    required this.onTap,
    this.bottomRule = false,
  });

  final String name;
  final String amount;
  final bool checked;
  final VoidCallback onTap;
  final bool bottomRule;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final theme = Theme.of(context);
    final rule = BorderSide(color: palette.borderSoft, width: ExomRule.hairline);
    return Semantics(
      container: true,
      checked: checked,
      button: true,
      label: amount.isEmpty ? name : '$name, $amount',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: rule,
                bottom: bottomRule ? rule : BorderSide.none,
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: checked ? palette.data : palette.textPrimary,
                          width: checked ? 2 : 1.5,
                        ),
                      ),
                      child: checked
                          ? Icon(ExomIcons.check, size: 26, color: palette.data)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: palette.textPrimary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                    if (amount.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Text(
                        amount,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: palette.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pushes a shopping-list screen over the whole app (root navigator, so the
/// shell's bar is not over it, as in the sketch) and closes it when the
/// router location changes, like the EXOM sheets (CC 11).
Future<T?> pushShoppingListRoute<T>(
  BuildContext context,
  WidgetBuilder builder,
) => pushPageAwareRoute<T>(
  context,
  MaterialPageRoute<T>(builder: builder),
  useRootNavigator: true,
);
