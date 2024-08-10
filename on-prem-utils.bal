import ballerina/http;
import ballerina/log;
import ballerina/lang.runtime;

// Configurable parameters.
configurable string onPremServerUrl = ?;

# Method to authenticate the user.
# 
# + user - The user object.
# + return - An error if the authentication fails.
isolated function authenticateUser(User user) returns error? {

    // Create a new HTTP client to connect to the on-premise server.
    final http:Client onPremClient = check new (onPremServerUrl, {
        auth: {
            username: user.username,
            password: user.password
        },
        secureSocket: {
            enable: false
        }
    });

    // Authenticate the user by invoking the on-premise server.
    http:Response response = check onPremClient->get("/scim2/Me");

    // Check if the authentication was unsuccessful.
    if response.statusCode == http:STATUS_UNAUTHORIZED {
        log:printError(string `Authentication failed for the user: ${user.id}. Invalid credentials`);
        return error("Invalid credentials");
    } else if response.statusCode != http:STATUS_OK {
        log:printError(string `Authentication failed for the user: ${user.id}.`);
        return error("Authentication failed");
    }
}

// A configurable map to hold user authentication data. I.e. username and passwords.
configurable map<string> userDB = ?;

# Method to simulate user authentication.
# 
# + user - The user object.
# + return - An error if the authentication fails.
isolated function authenticateUserSim(User user) returns error? {
    
    runtime:sleep(5);

    if userDB.hasKey(user.username) {
        if userDB[user.username] != user.password {
            return error("Invalid credentials");
        }
    } else {
        return error("User not found");
    }
}
