import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bean_sticker_models.dart';

class BeanNameWithSticker extends StatelessWidget {
  final String beanName;
  final TextStyle? textStyle;
  final double stickerSize;
  final bool showSticker;

  const BeanNameWithSticker({
    super.key,
    required this.beanName,
    this.textStyle,
    this.stickerSize = 16.0,
    this.showSticker = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showSticker) {
      return Text(beanName, style: textStyle);
    }

    return Consumer<BeanStickerProvider>(
      builder: (context, provider, child) {
        final stickerColor = provider.getStickerColor(beanName);

        if (stickerColor == null) {
          return Text(beanName, style: textStyle);
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: stickerSize,
              height: stickerSize,
              decoration: BoxDecoration(
                color: stickerColor,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 4),
            Text(beanName, style: textStyle),
          ],
        );
      },
    );
  }
}
