import ballerina/http;
import ballerina/log;
import ballerina/lang.runtime;

service / on new http:Listener(9090) {

    resource function post authenticate(User user) returns http:Ok|http:BadRequest|http:Unauthorized|http:InternalServerError {

        do {
            log:printInfo(string `Received on-prem authentication request for the user: ${user.id}.`);

            // Add fixed delay temporarily to simulate the delay in the on prem server.
            runtime:sleep(7);

            // // Retrieve user from Asgardeo for the given user id.
            // future<AsgardeoUser|error> asgardeoUserFuture = start getAsgardeoUser(user.id);

            // Try to authenticate the user with on prem server.
            error? authStatus = authenticateUser(user.cloneReadOnly());

            if authStatus is error {
                log:printError("Authentication failed with on prem server.");

                if authStatus.message() == "Invalid credentials" {
                    return <http:Unauthorized> {
                        body: {
                            message: "Invalid credentials!"
                        }
                    };
                } else {
                    return <http:InternalServerError> {
                        body: {
                            message: authStatus.message()
                        }
                    };
                }
            }

            log:printInfo("User authenticated with on prem server.");

            // // Wait for the response of Asgardeo invocation.
            // AsgardeoUser|error asgardeoUser = check wait asgardeoUserFuture;
            // log:printInfo("User retrieved from Asgardeo.");

            // if asgardeoUser is error {
            //     log:printError("Error occurred while retrieving user from Asgardeo.", asgardeoUser);

            //     return <http:InternalServerError> {
            //         body: {
            //             message: asgardeoUser.message()
            //         }
            //     };
            // }

            // // Validate the username.
            // if asgardeoUser.username !== user.username {
            //     log:printError(string `Invalid username provided for the user: ${user.id}.`);

            //     return <http:BadRequest> {
            //         body: {
            //             message: "Invalid username!"
            //         }
            //     };
            // }

            // log:printInfo("Username validated successfully.");
            log:printInfo(string `On prem authentication successful for the user: ${user.id}.`);

            // Return success response to Asgardeo.
            return <http:Ok> {
                body: {
                    message: "Successful"
                }
            };

        } on fail error err {
            log:printError(string `Error occurred while authenticating the user: ${user.id}.`, err);

            return <http:InternalServerError> {
                body: {
                    message: err.message()
                }
            };
        }
    }
}
