import 'dart:math';
import 'package:flutter/material.dart';

void main() => runApp(const KZApp());

class KZApp extends StatelessWidget {
  const KZApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: KZHome(),
    );
  }
}

class KZHome extends StatelessWidget {
  const KZHome({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Практична №4 — струми КЗ та стійкість'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Кабель (10 кВ)'),
              Tab(text: 'КЗ на шинах'),
              Tab(text: 'ХПнЕМ (режими)'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            CableCheckTab(),
            BusFaultTab(),
            HpnEmTab(),
          ],
        ),
      ),
    );
  }
}

String fmt(double v, [int d = 3]) => v.isNaN ? '—' : v.toStringAsFixed(d);

double parseNum(TextEditingController c) =>
    double.tryParse(c.text.replaceAll(',', '.').trim()) ?? double.nan;

InputDecoration deco(String label) => InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
    );

Widget gap([double h = 10]) => SizedBox(height: h);

/// ---------------- TAB 1: Cable check (thermal + dynamic) ----------------
class CableCheckTab extends StatefulWidget {
  const CableCheckTab({super.key});

  @override
  State<CableCheckTab> createState() => _CableCheckTabState();
}

class _CableCheckTabState extends State<CableCheckTab> {
  // Вхідні (під твої приклади 7.1/перевірки):
  final _Ik = TextEditingController(text: '10');     // кА (діюче значення КЗ, наприклад Ik'')
  final _t = TextEditingController(text: '0.6');     // с (час вимкнення КЗ)
  final _S = TextEditingController(text: '120');     // мм2 (переріз)
  final _k = TextEditingController(text: '115');     // матеріальний коеф. (вводиться вручну)
  final _ip = TextEditingController(text: '20');     // кА (ударний/піковий струм)
  final _ipAllow = TextEditingController(text: '25'); // кА (допустимий піковий для кабелю/АП)

  String _out = '';

  void _calc() {
    final Ik = parseNum(_Ik); // кА
    final t = parseNum(_t); // с
    final S = parseNum(_S); // мм2
    final k = parseNum(_k); // коеф.
    final ip = parseNum(_ip); // кА
    final ipAllow = parseNum(_ipAllow); // кА

    if ([Ik, t, S, k, ip, ipAllow].any((v) => v.isNaN)) {
      setState(() => _out = 'Помилка: перевір введені числа.');
      return;
    }
    if (t <= 0 || S <= 0 || k <= 0) {
      setState(() => _out = 'Помилка: t, S, k мають бути > 0.');
      return;
    }

    // Термічна стійкість (спрощена інженерна перевірка):
    // Sпотр >= (Ik * 1000) * sqrt(t) / k
    // Ik у кА -> А: *1000
    final Sneed = (Ik * 1000.0) * sqrt(t) / k;

    final thermalOK = S >= Sneed;

    // Динамічна стійкість (по піковому):
    final dynamicOK = ip <= ipAllow;

    setState(() {
      _out = [
        'Термічна стійкість:',
        'Sпотр = Ik·1000·√t / k = ${fmt(Sneed, 1)} мм²',
        'Sфакт = ${fmt(S, 1)} мм²  →  ${thermalOK ? "OK" : "НЕ OK"}',
        '',
        'Динамічна стійкість:',
        'iпік = ${fmt(ip, 2)} кА',
        'iдоп = ${fmt(ipAllow, 2)} кА  →  ${dynamicOK ? "OK" : "НЕ OK"}',
      ].join('\n');
    });
  }

  @override
  void dispose() {
    for (final c in [_Ik, _t, _S, _k, _ip, _ipAllow]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(String label, TextEditingController c) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: deco(label),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Перевірка кабелю на термічну та динамічну стійкість.\n'
            'Параметри k та допустимий iдоп береш з таблиць/прикладу.',
          ),
          gap(),
          field('Ik (кА) — діюче значення струму КЗ', _Ik),
          field('t (с) — час вимкнення КЗ', _t),
          field('S (мм²) — переріз кабелю', _S),
          field('k — коефіцієнт матеріалу/ізоляції', _k),
          field('iпік (кА) — ударний/піковий струм', _ip),
          field('iдоп (кА) — допустимий піковий струм', _ipAllow),
          ElevatedButton(onPressed: _calc, child: const Text('Розрахувати')),
          gap(),
          OutBox(text: _out),
        ],
      ),
    );
  }
}

/// ---------------- TAB 2: Short-circuit on 10kV busbars ----------------
/// Тут універсальний розрахунок 3ф та 1ф КЗ через еквівалентні опори.
/// Ти підставляєш Z з прикладу 7.2 (в Омах).
class BusFaultTab extends StatefulWidget {
  const BusFaultTab({super.key});

  @override
  State<BusFaultTab> createState() => _BusFaultTabState();
}

class _BusFaultTabState extends State<BusFaultTab> {
  final _Ull = TextEditingController(text: '10'); // кВ (лінійна напруга)
  final _Z1 = TextEditingController(text: '0.35'); // Ом (позитивна послідовність)
  final _Z2 = TextEditingController(text: '0.35'); // Ом (негативна)
  final _Z0 = TextEditingController(text: '1.00'); // Ом (нульова)
  final _kappa = TextEditingController(text: '1.8'); // коеф. піка (якщо треба)

  String _out = '';

  void _calc() {
    final U = parseNum(_Ull); // кВ
    final Z1 = parseNum(_Z1);
    final Z2 = parseNum(_Z2);
    final Z0 = parseNum(_Z0);
    final kappa = parseNum(_kappa);

    if ([U, Z1, Z2, Z0, kappa].any((v) => v.isNaN)) {
      setState(() => _out = 'Помилка: перевір введені числа.');
      return;
    }
    if (U <= 0 || Z1 <= 0 || Z2 <= 0 || Z0 <= 0) {
      setState(() => _out = 'Помилка: U та Z мають бути > 0.');
      return;
    }

    // 3-ф КЗ: Ik3 = Uф / Z1 = (Uл/√3)/Z1
    // U в кВ -> В: *1000, результат в А -> кА: /1000
    final Ik3_kA = ((U * 1000.0) / sqrt(3.0)) / Z1 / 1000.0;

    // 1-ф КЗ (на землю): Ik1 = 3*Uф/(Z1+Z2+Z0)
    final Ik1_kA =
        (3.0 * ((U * 1000.0) / sqrt(3.0))) / (Z1 + Z2 + Z0) / 1000.0;

    // Піковий (якщо потрібен): iпік ≈ kappa * √2 * Ik3
    final ip3_kA = kappa * sqrt(2.0) * Ik3_kA;

    setState(() {
      _out = [
        '3-ф КЗ:',
        'Ik3 = ${(fmt(Ik3_kA, 3))} кА',
        'iпік(3ф) ≈ κ·√2·Ik3 = ${fmt(ip3_kA, 2)} кА',
        '',
        '1-ф КЗ (на землю):',
        'Ik1 = ${fmt(Ik1_kA, 3)} кА',
        '',
        'Примітка: Z1/Z2/Z0 підставляй з прикладу 7.2 (еквівалент мережі).',
      ].join('\n');
    });
  }

  @override
  void dispose() {
    for (final c in [_Ull, _Z1, _Z2, _Z0, _kappa]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(String label, TextEditingController c) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: deco(label),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Розрахунок струмів 3-ф та 1-ф КЗ на шинах 10 кВ (під приклад 7.2).'),
          gap(),
          field('Uл (кВ) — лінійна напруга', _Ull),
          field('Z1 (Ом) — позитивна послідовність', _Z1),
          field('Z2 (Ом) — негативна послідовність', _Z2),
          field('Z0 (Ом) — нульова послідовність', _Z0),
          field('κ — коефіцієнт пікового струму (за потреби)', _kappa),
          ElevatedButton(onPressed: _calc, child: const Text('Розрахувати')),
          gap(),
          OutBox(text: _out),
        ],
      ),
    );
  }
}

/// ---------------- TAB 3: HPNEM (3 modes) + peak + thermal impulse ----------------
/// Робимо форму під ті величини, що видно у формульному фрагменті (прикл. 7.4),
/// де є складові від системи та двигунів, аперіодична складова, ударний струм і тепловий імпульс.
class HpnEmTab extends StatefulWidget {
  const HpnEmTab({super.key});

  @override
  State<HpnEmTab> createState() => _HpnEmTabState();
}

class _HpnEmTabState extends State<HpnEmTab> {
  // Дані (ти береш з прикладу 7.4 для кожного режиму і підставляєш)
  final _IpoSys = TextEditingController(text: '3.9'); // кА  Iп0.с
  final _IpoMot = TextEditingController(text: '0.7'); // кА  Iп0.д
  final _gamma = TextEditingController(text: '0.71'); // γ(τ) для двигунів
  final _tau = TextEditingController(text: '0.065'); // с  τ = tрз.min + tв.з (як в прикладі)
  final _TaSys = TextEditingController(text: '0.03'); // с  Ta.c
  final _TaMot = TextEditingController(text: '0.037'); // с Ta.д
  final _tOff = TextEditingController(text: '0.6'); // с час вимкнення КЗ
  final _t0 = TextEditingController(text: '0.01'); // с (у фрагменті є 0.01 у формулі ударного)

  String _out = '';

  void _calc() {
    final IpoS = parseNum(_IpoSys);
    final IpoD = parseNum(_IpoMot);
    final gamma = parseNum(_gamma);
    final tau = parseNum(_tau);
    final TaS = parseNum(_TaSys);
    final TaD = parseNum(_TaMot);
    final tOff = parseNum(_tOff);
    final t0 = parseNum(_t0);

    if ([IpoS, IpoD, gamma, tau, TaS, TaD, tOff, t0].any((v) => v.isNaN)) {
      setState(() => _out = 'Помилка: перевір введені числа.');
      return;
    }
    if ([TaS, TaD].any((v) => v <= 0)) {
      setState(() => _out = 'Помилка: Ta мають бути > 0.');
      return;
    }

    // Струм двигунів в момент τ: Iп.д(τ)= Iп0.д * γ(τ)
    final Ipd_tau = IpoD * gamma;

    // Аперіодичні складові в момент τ:
    // i_a = √2 * Iп0 * exp(-τ/Ta)
    final ia_sys = sqrt(2.0) * IpoS * exp(-tau / TaS);
    final ia_mot = sqrt(2.0) * IpoD * exp(-tau / TaD);

    // Ударний струм (піковий) для кожної складової:
    // iуд = √2 * Iп0 * (1 + exp(-t0/Ta))
    final iud_sys = sqrt(2.0) * IpoS * (1.0 + exp(-t0 / TaS));
    final iud_mot = sqrt(2.0) * IpoD * (1.0 + exp(-t0 / TaD));

    // Сумарно (грубо): беремо суми (для звіту зазвичай окремо теж показують)
    final iud_sum = iud_sys + iud_mot;

    // Еквівалентна Ta схеми (як у фрагменті формул: зважування по Iп0)
    final Ta_eq = (TaS * IpoS + TaD * IpoD) / (IpoS + IpoD);

    // Постійна часу періодичної складової двигунів:
    // Tп.д = -τ / ln(γ(τ))  (як у фрагменті)
    final Tp_mot = (gamma > 0 && gamma < 1) ? (-tau / log(gamma)) : double.nan;

    // Тепловий імпульс (за формою з фрагмента):
    // Bk = Iп0.c^2*(tвимк + Ta_eq) + Iп0.д^2*(0.5*Tp.д + Ta_eq) + 2*Iп0.c*Iп0.д*(Tp.д + Ta_eq)
    // (якщо Tp.д невалідний — пропустимо)
    double Bk = double.nan;
    if (!Tp_mot.isNaN) {
      Bk = pow(IpoS, 2) * (tOff + Ta_eq) +
          pow(IpoD, 2) * (0.5 * Tp_mot + Ta_eq) +
          2 * IpoS * IpoD * (Tp_mot + Ta_eq);
    }

    setState(() {
      _out = [
        'Двигуни в момент τ:',
        'Iп.д(τ) = Iп0.д · γ(τ) = ${fmt(Ipd_tau, 3)} кА',
        '',
        'Аперіодична складова в момент τ:',
        'iа.с(τ) = √2·Iп0.с·e^(−τ/Ta.с) = ${fmt(ia_sys, 3)} кА',
        'iа.д(τ) = √2·Iп0.д·e^(−τ/Ta.д) = ${fmt(ia_mot, 3)} кА',
        '',
        'Ударний струм:',
        'iуд.с = √2·Iп0.с·(1+e^(−t0/Ta.с)) = ${fmt(iud_sys, 3)} кА',
        'iуд.д = √2·Iп0.д·(1+e^(−t0/Ta.д)) = ${fmt(iud_mot, 3)} кА',
        'iуд.Σ ≈ ${fmt(iud_sum, 3)} кА',
        '',
        'Допоміжні:',
        'Ta.екв = ${fmt(Ta_eq, 4)} с',
        'Tп.д = −τ / ln(γ) = ${fmt(Tp_mot, 4)} с',
        '',
        'Тепловий імпульс:',
        'Bk = ${fmt(Bk, 3)} (кА²·с)',
        '',
        'Примітка: для НОРМ/МІН/АВАР режимів просто підставляєш свої Iп0, γ, Ta та часи.',
      ].join('\n');
    });
  }

  @override
  void dispose() {
    for (final c in [_IpoSys, _IpoMot, _gamma, _tau, _TaSys, _TaMot, _tOff, _t0]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(String label, TextEditingController c) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: deco(label),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ХПнЕМ (приклад 7.4): складові від системи та двигунів, ударний струм і тепловий імпульс.',
          ),
          gap(),
          field('Iп0.с (кА) — початкова періодична складова (система)', _IpoSys),
          field('Iп0.д (кА) — початкова періодична складова (двигуни)', _IpoMot),
          field('γ(τ) — коефіцієнт за графіком/прикладом', _gamma),
          field('τ (с) — момент часу (наприклад tрз.min + tв.з)', _tau),
          field('Ta.с (с) — стала часу аперіодичної складової (система)', _TaSys),
          field('Ta.д (с) — стала часу аперіодичної складової (двигуни)', _TaMot),
          field('tвимк (с) — час вимкнення КЗ', _tOff),
          field('t0 (с) — для ударного струму (часто 0.01)', _t0),
          ElevatedButton(onPressed: _calc, child: const Text('Розрахувати')),
          gap(),
          OutBox(text: _out),
        ],
      ),
    );
  }
}

/// ---------------- small output box ----------------
class OutBox extends StatelessWidget {
  final String text;
  const OutBox({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text.isEmpty ? 'Натисни «Розрахувати».' : text,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
    );
  }
}