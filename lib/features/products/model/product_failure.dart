import 'package:dartz/dartz.dart';

abstract class ProductFailure {
  final String message;

  ProductFailure(this.message);
}

class ServerFailure extends ProductFailure {
  ServerFailure(String message) : super(message);
}

class NoProductsFailure extends ProductFailure {
  NoProductsFailure() : super('No products available');
}