import 'package:equatable/equatable.dart';
import 'package:traincode/features/products/model/product_model.dart';
import 'package:traincode/features/products/model/product_failure.dart';

abstract class ProductsState extends Equatable {
  @override
  List<Object> get props => [];
}

class ProductsInitial extends ProductsState {}

class ProductsLoading extends ProductsState {}

class ProductsLoaded extends ProductsState {
  final List<Product> products;

  ProductsLoaded(this.products);

  @override
  List<Object> get props => [products];
}

class ProductsError extends ProductsState {
  final ProductFailure failure;

  ProductsError(this.failure);

  @override
  List<Object> get props => [failure];
}