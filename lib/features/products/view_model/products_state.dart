import 'package:equatable/equatable.dart';
import 'package:traincode/features/products/model/product_failure.dart';

abstract class ProductsState extends Equatable {
  @override
  List<Object> get props => [];
}

class ProductsInitial extends ProductsState {}

class ProductsLoading extends ProductsState {}

class ProductsLoaded extends ProductsState {
  final List<Map<String, dynamic>> collections;

  ProductsLoaded(this.collections);

  @override
  List<Object> get props => [collections];
}

class ProductsError extends ProductsState {
  final ProductFailure failure;

  ProductsError(this.failure);

  @override
  List<Object> get props => [failure];
}
