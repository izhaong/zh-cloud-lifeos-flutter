// #387：locale 声明必须诚实——声明支持的语言都要真的可达。
//
// 此前 `supportedLocales` 含 `en_US`，但 `locale:` 写死 `zh_CN`，
// 英文那档运行时不可达；TC-REG-104「切英文无中文残留」因此结构上做不到。
//
// 这里断言的是 main.dart 里的**常量**（kAppLocale / kAppSupportedLocales），
// 不拉起整个应用——拉起会要求 ProviderScope + 一整套注入，与这条判据无关。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_launcher/main.dart';

void main() {
  test('#387 只声明中文：不再有不可达的 en_US', () {
    expect(kAppSupportedLocales, const [Locale('zh', 'CN')]);
    expect(
      kAppSupportedLocales.map((l) => l.languageCode).toSet(),
      {'zh'},
      reason: '声明了却不可达的语言就是假能力',
    );
  });

  test('#387 断言用的 locale 与实际生效的 locale 一致', () {
    expect(kAppLocale, const Locale('zh', 'CN'));
    expect(
      kAppSupportedLocales.contains(kAppLocale),
      isTrue,
      reason: '生效 locale 必须在自己声明的支持列表里',
    );
  });
}
