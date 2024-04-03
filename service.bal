import ballerina/http;
import ballerina/log;

service / on new http:Listener(9090) {

    resource function post migrate\-password(User user) returns http:Ok|http:BadRequest|http:InternalServerError {

        do {
            log:printInfo(string `Start password migration for the user: ${user.id}.`);

            // Retrieve user from Asgardeo for the given user id.
            future<AsgardeoUser|error> asgardeoUserFuture = start getAsgardeoUser(user.id);

            // Try to authenticate the user with on prem server.
            check authenticateUser(user.cloneReadOnly());

            // Wait for the response of Asgardeo invocation.
            AsgardeoUser|error asgardeoUser = check wait asgardeoUserFuture;

            if asgardeoUser is error {
                log:printError(string `Error occurred while retrieving user from Asgardeo for the user: ${user.id}.`, asgardeoUser);

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
