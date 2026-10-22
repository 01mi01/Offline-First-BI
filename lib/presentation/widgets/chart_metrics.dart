import 'package:flutter/widgets.dart';

double scaledAxisSize(BuildContext context, double base) =>
    MediaQuery.textScalerOf(context).scale(base);
