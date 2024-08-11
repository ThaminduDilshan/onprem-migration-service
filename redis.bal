import ballerinax/redis;
import ballerina/log;

configurable RedisConfig redisConfig = ?;

final redis:Client redisClient = check new (
    connection = {
        host: redisConfig.host,
        port: redisConfig.port,
        username: redisConfig.username,
        password: redisConfig.password,
        options: {
            connectionTimeout: 5000
        }
    }
);

isolated function getContextFromCache(string contextId) returns (AuthenticationContext|null|error) {

    string|redis:Error? cacheValue = redisClient->get(contextId);

    if cacheValue is redis:Error {
        log:printError(string `${contextId}: Error occurred while retrieving context from the cache.`, cacheValue);
        return error("Error occurred while retrieving context from the cache.");
    }

    if cacheValue == () {
        log:printError(string `${contextId}: Context not found in the cache.`);
        return null;
    }

    AuthenticationContext|error context = cacheValue.fromJsonStringWithType(AuthenticationContext);

    if context is error {
        log:printError(string `${contextId}: Error occurred while parsing the context.`, context);
        return error("Error occurred while parsing the context.");
    }

    log:printInfo(string `${contextId}: Context retrieved successfully from the cache.`);

    return context;
}

isolated function addContextToCache(string contextId, AuthenticationContext context) returns error? {

    string|error cacheValue = context.toJsonString();

    if cacheValue is error {
        log:printError(string `${contextId}: Error occurred while serializing the context.`, cacheValue);
        return error("Error occurred while serializing the context.");
    }

    var result = redisClient->setEx(contextId, cacheValue, redisConfig.cacheExpiryTime);

    if result is redis:Error {
        log:printError(string `${contextId}: Error occurred while adding context to the cache.`, result);
        return error("Error occurred while adding context to the cache.");
    }

    if result != "OK" {
        log:printError(string `${contextId}: Adding context to the cache failed.`);
        return error("Adding context to the cache failed.");
    }

    log:printInfo(string `${contextId}: Context added successfully to the cache.`);
}

isolated function removeContextFromCache(string contextId) returns error? {

    var result = redisClient->del([contextId]);

    if result is redis:Error {
        log:printError(string `${contextId}: Error occurred while removing context from the cache.`, result);
        return error("Error occurred while removing context from the cache.");
    }

    if result == 0 {
        log:printError(string `${contextId}: Context not found in the cache.`);
        return error("Context not found in the cache.");
    }

    log:printInfo(string `${contextId}: Context removed successfully from the cache.`);
}
