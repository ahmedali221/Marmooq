import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:marmooq/core/utils/responsive_utils.dart';

class ShimmerWidgets {
  static Widget shimmerBase({
    required Widget child,
    Color? baseColor,
    Color? highlightColor,
  }) {
    return Shimmer.fromColors(
      baseColor: baseColor ?? Colors.grey[300]!,
      highlightColor: highlightColor ?? Colors.grey[100]!,
      child: child,
    );
  }

  // Product card shimmer
  static Widget productCardShimmer(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image shimmer
          Container(
            height: ResponsiveUtils.getResponsiveHeight(context, mobile: 160),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(
                  ResponsiveUtils.getResponsiveBorderRadius(
                    context,
                    mobile: 12,
                  ),
                ),
                topRight: Radius.circular(
                  ResponsiveUtils.getResponsiveBorderRadius(
                    context,
                    mobile: 12,
                  ),
                ),
              ),
            ),
          ),
          Flexible(
            child: Padding(
              padding: EdgeInsets.all(
                ResponsiveUtils.getResponsiveSpacing(context, mobile: 12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title shimmer
                  Container(
                    height: ResponsiveUtils.getResponsiveHeight(
                      context,
                      mobile: 14,
                    ),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(
                      context,
                      mobile: 6,
                    ),
                  ),
                  // Price shimmer
                  Container(
                    height: ResponsiveUtils.getResponsiveHeight(
                      context,
                      mobile: 12,
                    ),
                    width: ResponsiveUtils.getResponsiveWidth(
                      context,
                      mobile: 70,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(
                      context,
                      mobile: 8,
                    ),
                  ),
                  // Button shimmer
                  Container(
                    height: ResponsiveUtils.getResponsiveHeight(
                      context,
                      mobile: 32,
                    ),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.getResponsiveBorderRadius(
                          context,
                          mobile: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Collection header shimmer
  static Widget collectionHeaderShimmer(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ResponsiveUtils.getResponsiveSpacing(context, mobile: 20),
        ResponsiveUtils.getResponsiveSpacing(context, mobile: 20),
        ResponsiveUtils.getResponsiveSpacing(context, mobile: 20),
        ResponsiveUtils.getResponsiveSpacing(context, mobile: 16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Collection name shimmer
                Container(
                  height: ResponsiveUtils.getResponsiveHeight(
                    context,
                    mobile: 20,
                  ),
                  width: ResponsiveUtils.getResponsiveWidth(
                    context,
                    mobile: 150,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: 4,
                  ),
                ),
                // Product count shimmer
                Container(
                  height: ResponsiveUtils.getResponsiveHeight(
                    context,
                    mobile: 14,
                  ),
                  width: ResponsiveUtils.getResponsiveWidth(
                    context,
                    mobile: 80,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          // View all button shimmer
          Container(
            height: ResponsiveUtils.getResponsiveHeight(context, mobile: 32),
            width: ResponsiveUtils.getResponsiveWidth(context, mobile: 80),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Product details shimmer
  static Widget productDetailsShimmer(BuildContext context) {
    return Column(
      children: [
        // Image shimmer
        Container(
          height: ResponsiveUtils.getResponsiveHeight(context, mobile: 350),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(
                ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 16),
              ),
              bottomRight: Radius.circular(
                ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 16),
              ),
            ),
          ),
        ),
        // Content shimmer
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(
                  ResponsiveUtils.getResponsiveBorderRadius(
                    context,
                    mobile: 24,
                  ),
                ),
                topRight: Radius.circular(
                  ResponsiveUtils.getResponsiveBorderRadius(
                    context,
                    mobile: 24,
                  ),
                ),
              ),
            ),
            child: Padding(
              padding: ResponsiveUtils.getResponsivePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name and price shimmer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Container(
                          height: ResponsiveUtils.getResponsiveHeight(
                            context,
                            mobile: 22,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: ResponsiveUtils.getResponsiveSpacing(
                          context,
                          mobile: 16,
                        ),
                      ),
                      Container(
                        height: ResponsiveUtils.getResponsiveHeight(
                          context,
                          mobile: 20,
                        ),
                        width: ResponsiveUtils.getResponsiveWidth(
                          context,
                          mobile: 100,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(
                      context,
                      mobile: 12,
                    ),
                  ),
                  // Description shimmer
                  Container(
                    height: ResponsiveUtils.getResponsiveHeight(
                      context,
                      mobile: 120,
                    ),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.getResponsiveBorderRadius(
                          context,
                          mobile: 12,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(
                      context,
                      mobile: 24,
                    ),
                  ),
                  // Action buttons shimmer
                  Row(
                    children: [
                      Container(
                        height: ResponsiveUtils.getResponsiveHeight(
                          context,
                          mobile: 50,
                        ),
                        width: ResponsiveUtils.getResponsiveWidth(
                          context,
                          mobile: 60,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.getResponsiveBorderRadius(
                              context,
                              mobile: 12,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: ResponsiveUtils.getResponsiveSpacing(
                          context,
                          mobile: 12,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: ResponsiveUtils.getResponsiveHeight(
                            context,
                            mobile: 50,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(
                              ResponsiveUtils.getResponsiveBorderRadius(
                                context,
                                mobile: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Cart item shimmer
  static Widget cartItemShimmer(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(
        bottom: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 16),
        ),
      ),
      child: Padding(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Row(
          children: [
            // Product image shimmer
            Container(
              width: ResponsiveUtils.getResponsiveWidth(context, mobile: 90),
              height: ResponsiveUtils.getResponsiveHeight(context, mobile: 90),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getResponsiveBorderRadius(
                    context,
                    mobile: 12,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16),
            ),
            // Product details shimmer
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name shimmer
                  Container(
                    height: ResponsiveUtils.getResponsiveHeight(
                      context,
                      mobile: 16,
                    ),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(
                      context,
                      mobile: 8,
                    ),
                  ),
                  // Quantity controls shimmer
                  Container(
                    height: ResponsiveUtils.getResponsiveHeight(
                      context,
                      mobile: 32,
                    ),
                    width: ResponsiveUtils.getResponsiveWidth(
                      context,
                      mobile: 120,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.getResponsiveBorderRadius(
                          context,
                          mobile: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Price shimmer
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  height: ResponsiveUtils.getResponsiveHeight(
                    context,
                    mobile: 16,
                  ),
                  width: ResponsiveUtils.getResponsiveWidth(
                    context,
                    mobile: 80,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: 4,
                  ),
                ),
                Container(
                  height: ResponsiveUtils.getResponsiveHeight(
                    context,
                    mobile: 12,
                  ),
                  width: ResponsiveUtils.getResponsiveWidth(
                    context,
                    mobile: 60,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Grid shimmer for collections
  static Widget gridShimmer(BuildContext context, {int itemCount = 6}) {
    return GridView.builder(
      padding: ResponsiveUtils.getResponsivePadding(context),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ResponsiveUtils.getResponsiveGridCrossAxisCount(
          context,
        ),
        childAspectRatio: ResponsiveUtils.getResponsiveGridChildAspectRatio(
          context,
        ),
        crossAxisSpacing: ResponsiveUtils.getResponsiveSpacing(
          context,
          mobile: 12,
        ),
        mainAxisSpacing: ResponsiveUtils.getResponsiveSpacing(
          context,
          mobile: 16,
        ),
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) =>
          shimmerBase(child: productCardShimmer(context)),
    );
  }

  // Horizontal list shimmer
  static Widget horizontalListShimmer(
    BuildContext context, {
    int itemCount = 6,
  }) {
    return SizedBox(
      height: ResponsiveUtils.getResponsiveHeight(context, mobile: 280),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16),
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) => Container(
          width: ResponsiveUtils.getResponsiveCardWidth(context),
          margin: EdgeInsets.only(
            right: ResponsiveUtils.getResponsiveSpacing(context, mobile: 12),
            bottom: ResponsiveUtils.getResponsiveSpacing(context, mobile: 20),
          ),
          child: shimmerBase(child: productCardShimmer(context)),
        ),
      ),
    );
  }
}
