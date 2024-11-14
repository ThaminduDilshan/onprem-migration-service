import ballerina/http;
import ballerina/log;
import ballerina/uuid;

//
// In memory map implementation.
//

isolated map<AuthenticationContext> userAuthContextMap = {};

isolated function pushToContext(string contextId, AuthenticationContext context) {

    lock {
        userAuthContextMap[contextId] = context;
    }
}

isolated function isContextExists(string contextId) returns boolean {

    lock {
        return userAuthContextMap.hasKey(contextId);
    }
}

isolated function popFromContext(string contextId) returns AuthenticationContext {

    lock {
        return userAuthContextMap.remove(contextId);
    }
}

service / on new http:Listener(9090) {

    resource function post start\-authentication(http:Caller caller, User user) {

        string contextId = uuid:createType1AsString();

        log:printInfo(string `${contextId}: Received authentication request for the user: ${user.id}.`);

        do {
            // Create future to authenticate user with the on prem server.
            // future<error?> authStatusFuture = start authenticateUser(user.cloneReadOnly());
            future<error?> authStatusFuture = start authenticateUserSim(user.cloneReadOnly());

            // Return request received response to Identity Server.
            check caller->respond(<http:Ok>{
                body: {
                    message: "Received",
                    contextId: contextId
                }
            });

            // // Add fixed delay temporarily to simulate a delay in the on prem server.
            // runtime:sleep(5);

            // // Retrieve user from Identity Server for the given user id.
            // future<IdentityServerUser|error> IdentityServerUserFuture = start getIdentityServerUser(user.id);

            // Wait for the response of on prem invocation.
            error? authStatus = check wait authStatusFuture;

            if authStatus is error {
                log:printInfo(string `${contextId}: Authentication failed with on prem server.`);

                if authStatus.message() == "Invalid credentials" {
                    log:printInfo(string `${contextId}: Invalid credentials provided for the user: ${user.id}.`);

                    AuthenticationContext context = {
                        username: user.username,
                        status: "FAIL",
                        message: "Invalid credentials"
                    };
                    
                    pushToContext(contextId, context);
                    // error? response = addContextToCache(contextId, context);
                    // if response is error {
                    //     log:printError(string `${contextId}: Error occurred while adding context to the cache.`, response);
                    // }

                } else {
                    log:printError(string `${contextId}: Error occurred while authenticating the user: ${user.id}.`, authStatus);

                    AuthenticationContext context = {
                        username: user.username,
                        status: "FAIL",
                        message: "Something went wrong"
                    };

                    pushToContext(contextId, context);
                    // error? response = addContextToCache(contextId, context);
                    // if response is error {
                    //     log:printError(string `${contextId}: Error occurred while adding context to the cache.`, response);
                    // }
                }
            }

            log:printInfo(string `${contextId}: User authenticated with on prem server.`);

            // // Wait for the response of Identity Server invocation.
            // IdentityServerUser|error IdentityServerUser = check wait IdentityServerUserFuture;
            // log:printInfo(string `${contextId}: User retrieved from Identity Server.`);

            // if IdentityServerUser is error {
            //     log:printInfo(string `${contextId}: Error occurred while retrieving user from Identity Server.`, IdentityServerUser);

            //     fail error("Something went wrong.");
            // }

            // // Validate the username.
            // if IdentityServerUser.username !== user.username {
            //     log:printInfo(string `${contextId}: Invalid username provided for the user: ${user.id}.`);

            //     fail error("Invalid credentials");
            // }

            log:printInfo(string `${contextId}: Username validated successfully.`);
            log:printInfo(string `${contextId}: On prem authentication successful for the user: ${user.id}.`);

            // Add successful authentication context to the map.
            AuthenticationContext context = {
                username: user.username,
                status: "SUCCESS",
                message: "Authenticated successful"
            };

            pushToContext(contextId, context);
            // error? response = addContextToCache(contextId, context);
            // if response is error {
            //     log:printError(string `${contextId}: Error occurred while adding context to the cache.`, response);
            // }

        } on fail error err {
            if err.message() == "Invalid credentials" {
                log:printInfo(string `${contextId}: Invalid credentials provided for the user: ${user.id}.`);

                AuthenticationContext context = {
                    username: user.username,
                    status: "FAIL",
                    message: "Invalid credentials"
                };

                pushToContext(contextId, context);
                // error? response = addContextToCache(contextId, context);
                // if response is error {
                //     log:printError(string `${contextId}: Error occurred while adding context to the cache.`, response);
                // }
            } else {
                log:printError(string `${contextId}: Error occurred while authenticating the user: ${user.id}.`, err);

                AuthenticationContext context = {
                    username: user.username,
                    status: "FAIL",
                    message: "Something went wrong"
                };

                pushToContext(contextId, context);
                // error? response = addContextToCache(contextId, context);
                // if response is error {
                //     log:printError(string `${contextId}: Error occurred while adding context to the cache.`, response);
                // }
            }
        }
    }

    //
    // In memory map implementation.
    //

    resource function post authentication\-status(AuthenticationStatusRequest authStatus) returns http:Ok|http:BadRequest {

        string contextId = authStatus.contextId;
        string username = authStatus.username;

        log:printInfo(string `Received authentication status check for the context id: ${contextId}.`);

        if (isContextExists(contextId)) {
            AuthenticationContext? context = popFromContext(contextId);

            if (context == null) {
                log:printInfo(string `${contextId}: Error occurred while retrieving the authentication status. Context not found.`);

                return <http:BadRequest>{
                    body: {
                        message: "Invalid context id"
                    }
                };
            }

            log:printInfo(string `${contextId}: Authentication status retrieved successfully.`);

            if (context.username == username) {
                log:printInfo(string `${contextId}: Username validated successfully.`);

                return <http:Ok>{
                    body: {
                        status: context.status,
                        message: context.message
                    }
                };
            } else {
                log:printInfo(string `${contextId}: Provided username does NOT match with the context username.`);

                return <http:Ok>{
                    body: {
                        status: "FAIL",
                        message: "Invalid request"
                    }
                };
            }
        } else {
            log:printInfo(string `Authentication status not found for the context id: ${contextId}.`);

            return <http:BadRequest>{
                body: {
                    message: "Invalid context id"
                }
            };
        }
    }

    //
    // Redis cache implementation.
    //

    // resource function post authentication\-status(AuthenticationStatusRequest authStatus) returns http:Ok|http:BadRequest {

    //     string contextId = authStatus.contextId;
    //     string username = authStatus.username;

    //     log:printInfo(string `Received authentication status check for the context id: ${contextId}.`);

    //     AuthenticationContext|null|error context = getContextFromCache(contextId);

    //     if context is error {
    //         log:printInfo(string `${contextId}: Error occurred while retrieving the authentication status.`, context);

    //         return <http:BadRequest>{
    //             body: {
    //                 message: "Something went wrong"
    //             }
    //         };
    //     }

    //     if context == null {
    //         log:printInfo(string `Authentication status not found for the context id: ${contextId}.`);

    //         return <http:BadRequest>{
    //             body: {
    //                 message: "Invalid context id"
    //             }
    //         };
    //     }

    //     error? response = removeContextFromCache(contextId);
    //     if response is error {
    //         log:printError(string `${contextId}: Error occurred while removing context from the cache.`, response);
    //     }

    //     log:printInfo(string `${contextId}: Authentication status retrieved successfully.`);

    //     if (context.username == username) {
    //         log:printInfo(string `${contextId}: Username validated successfully.`);

    //         return <http:Ok>{
    //             body: {
    //                 status: context.status,
    //                 message: context.message
    //             }
    //         };
    //     } else {
    //         log:printInfo(string `${contextId}: Provided username does NOT match with the context username.`);

    //         return <http:Ok>{
    //             body: {
    //                 status: "FAIL",
    //                 message: "Invalid request"
    //             }
    //         };
    //     }
    // }

    //
    // In memory map implementation.
    //

    resource function get authentication\-status(string contextId) returns http:Ok {

        log:printInfo(string `Received status polling query for the context id: ${contextId}.`);

        if (isContextExists(contextId)) {
            log:printInfo(string `${contextId}: Context found for the status query.`);

            return <http:Ok>{
                body: {
                    status: "COMPLETE"
                }
            };
        } else {
            log:printInfo(string `${contextId}: Context not found for the status query.`);

            return <http:Ok>{
                body: {
                    status: "PENDING"
                }
            };
        }
    }

    //
    // Redis cache implementation.
    //

    // resource function get authentication\-status(string contextId) returns http:Ok {

    //     log:printInfo(string `Received status polling query for the context id: ${contextId}.`);

    //     AuthenticationContext|null|error context = getContextFromCache(contextId);

    //     if context is error {
    //         log:printInfo(string `${contextId}: Error while retrieving the context.`, context);

    //         return <http:Ok>{
    //             body: {
    //                 status: "PENDING"
    //             }
    //         };
    //     }

    //     if context == null {
    //         log:printInfo(string `${contextId}: Context not found for the status query.`);

    //         return <http:Ok>{
    //             body: {
    //                 status: "PENDING"
    //             }
    //         };
    //     }

    //     log:printInfo(string `${contextId}: Context found for the status query.`);

    //     return <http:Ok>{
    //         body: {
    //             status: "COMPLETE"
    //         }
    //     };
    // }
}
