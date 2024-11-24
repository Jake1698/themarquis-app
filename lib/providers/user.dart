import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:marquis_v2/env.dart';
import 'package:marquis_v2/models/user.dart';
import 'package:marquis_v2/providers/app_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:http/http.dart' as http;
import 'package:starknet/starknet.dart';

part "user.g.dart";

final baseUrl = environment['build'] == 'DEBUG'
    ? environment['apiUrlDebug']
    : environment['apiUrl'];

@Riverpod(keepAlive: true)
class User extends _$User {
  //Details Declaration
  Box<UserData>? _hiveBox;

  @override
  UserData? build() {
    _hiveBox ??= Hive.box<UserData>("user");
    return _hiveBox!.get("user");
  }

  Future<void> getUser() async {
    final url = Uri.parse('$baseUrl/user/info');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': ref.read(appStateProvider).bearerToken
      },
    );
    if (response.statusCode != 200) {
      throw HttpException(
          'Request error with status code ${response.statusCode}.\nResponse:${utf8.decode(response.bodyBytes)}');
    }
    final decodedResponse = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
    final user = UserData(
      id: decodedResponse['user']['id'].toString(),
      email: decodedResponse['user']['email'],
      role: decodedResponse['user']['role'],
      status: decodedResponse['user']['status'],
      points: decodedResponse['user']['points'],
      referredBy: decodedResponse['user']['referred_by'].toString(),
      referralId: decodedResponse['user']['referral_id'],
      walletId: decodedResponse['user']['wallet_id'],
      profileImageUrl: decodedResponse['user']['profile_image_url'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          decodedResponse['user']['created_at'] * 1000),
      updatedAt: DateTime.fromMicrosecondsSinceEpoch(
          decodedResponse['user']['updated_at'] * 1000),
      referralCode: decodedResponse['referral_code'],
      accountAddress: decodedResponse['account_address'],
      sessionId: decodedResponse['session_id'],
    );
    await _hiveBox!.put("user", user);
    state = user;
  }

  Future<void> clearData() async {
    await _hiveBox!.delete("user");
    // state = null;
    ref.invalidateSelf();
  }

  Future<void> editUser(
    String firstName,
    String lastName,
    DateTime birthdate,
    String gender,
    String country,
    String fieldOfCareer,
  ) async {
    // await ref.read(natsServiceProvider.notifier).makeMicroserviceRequest(
    //       "jomfi.editUser.<user>",
    //       jsonEncode({
    //         'firstName': firstName,
    //         'lastName': lastName,
    //         'birthdate': birthdate.toIso8601String(),
    //         'gender': gender,
    //         'country': country,
    //         'fieldOfCareer': fieldOfCareer,
    //       }),
    //     );
    // state = state?.copyWith(
    //   firstName: firstName,
    //   lastName: lastName,
    //   birthdate: birthdate,
    //   gender: gender,
    //   country: country,
    //   fieldOfCareer: fieldOfCareer,
    // );
  }

  Future<List<Map<String, String>>> getSupportedTokens() async {
    final url = Uri.parse('$baseUrl/game/supported-tokens');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': ref.read(appStateProvider).bearerToken
      },
    );
    if (response.statusCode != 200) {
      throw HttpException(
          'Request error with status code ${response.statusCode}.\nResponse:${utf8.decode(response.bodyBytes)}');
    }
    final List<Map<String, String>> results = [];
    final decodedResponse =
        jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    for (var e in decodedResponse) {
      results.add({
        'tokenAddress': e['address'],
        'tokenName': e['name'],
      });
    }
    return results;
  }

  Future<BigInt> getTokenBalance(String tokenAddress) async {
    if (state == null) return BigInt.from(0);

    final provider = JsonRpcProvider.infuraMainnet;
    final accountAddress = Felt.fromHexString(state!.accountAddress);
    final ethContractAddress = Felt.fromHexString(tokenAddress);

    try {
      final response = await provider.call(
        request: FunctionCall(
          contractAddress: ethContractAddress,
          entryPointSelector: getSelectorByName('balanceOf'),
          calldata: [accountAddress],
        ),
        blockId: const BlockId.blockTag("latest"),
      );

      return response.when(
        error: (error) {
          throw Exception("Error fetching balance: $error");
        },
        result: (result) {
          return Uint256.fromFeltList(result).toBigInt();
        },
      );
    } catch (e) {
      throw Exception("Failed to fetch token balance: $e");
    }
  }
}
