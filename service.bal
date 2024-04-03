import ballerina/http;
import ballerina/log;

service / on new http:Listener(9090) {

    resource function post migrate\-password(User user) returns http:Ok|http:BadRequest|http:Unauthorized|http:InternalServerError {

        do {
            log:printInfo(string `Start password migration for the user: ${user.id}.`);

            // Retrieve user from Asgardeo for the given user id.
            future<AsgardeoUser|error> asgardeoUserFuture = start getAsgardeoUser(user.id);

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

            // Wait for the response of Asgardeo invocation.
            AsgardeoUser|error asgardeoUser = check wait asgardeoUserFuture;
            log:printInfo("User retrieved from Asgardeo.");

            if asgardeoUser is error {
                log:printError("Error occurred while retrieving user from Asgardeo.", asgardeoUser);

                return <http:InternalServerError> {
                    body: {
                        message: asgardeoUser.message()
                    }
                };
            }

            // Validate the username.
            if asgardeoUser.username !== user.username {
                log:printError(string `Invalid username provided for the user: ${user.id}.`);

                return <http:BadRequest> {
                    body: {
                        message: "Invalid username!"
                    }
                };
            }

            log:printInfo("Username validated successfully.");

            // Try to change the password of the Asgardeo user.
            check changeUserPassword(asgardeoUser, user.password);

        } on fail error err {
            log:printError(string `Error occurred while migrating password for the user: ${user.id}.`, err);

            return <http:InternalServerError> {
                body: {
                    message: err.message()
                }
            };
        }

        log:printInfo(string `Password migrated successfully for the user: ${user.id}.`);

        return <http:Ok> {
            body: {
                message: "Password migrated successfully!"
            }
        };
    }
}
