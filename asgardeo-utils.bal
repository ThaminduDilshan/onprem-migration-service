import ballerina/http;
import ballerina/log;
import ballerina/regex;

// Configurable parameters.
configurable string asgardeoUrl = ?;
configurable AsgardeoAppConfig asgardeoAppConfig = ?;

// Asgardeo scopes to invoke the APIs.
const ASGARDEO_USER_VIEW_SCOPE = "internal_user_mgt_view";
const ASGARDEO_USER_UPDATE_SCOPE = "internal_user_mgt_update";

final string asgardeoScopes = string:'join(" ", ASGARDEO_USER_VIEW_SCOPE, ASGARDEO_USER_UPDATE_SCOPE);

final http:Client asgardeoClient = check new (asgardeoUrl, {
    auth: {
        ...asgardeoAppConfig,
        scopes: asgardeoScopes
    }
});

# Retrieve the given user from Asgardeo.
# 
# + id - The id of the user.
# + return - The AsgardeoUser if the user is found, else an error.
isolated function getAsgardeoUser(string id) returns AsgardeoUser|error {

    // Retrieve user from the Asgardeo server given the user id.
    json|error jsonResponse = asgardeoClient->get("/scim2/Users/" + id);

    // Handle error response.
    if jsonResponse is error {
        log:printError(string `Error while fetching Asgardeo user for the id: ${id}.`, jsonResponse);
        return error("Error while fetching the user.");
    }

    AsgardeoUserResponse response = check jsonResponse.cloneWithType(AsgardeoUserResponse);

    if response.userName == "" {
        log:printError(string `A user not found for the id: ${id}.`);
        return error("User not found.");
    }

    // Extract the username from the response.
    string username = regex:split(response.userName, "/")[1];

    log:printInfo("Successfully retrieved the username from Asgardeo.");

    // Return the user object.
    return {
        id: response.id,
        username: username
    };
}

# Change the password of the given user in Asgardeo.
# 
# + asgardeoUser - The user object.
# + password - The new password.
# + return - An error if the operation fails.
isolated function changeUserPassword(AsgardeoUser asgardeoUser, string password) returns error? {

    // Scim patch request body.
    json requestBody = {
        schemas: ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
        Operations: [
            {
                op: "replace",
                value: {
                    "password": password
                }
            },
            {
                op: "replace",
                value: {
                    "urn:scim:wso2:schema": {
                        "is_migrated": true
                    }
                }
            }
        ]
    };

    log:printInfo("Changing the password of the user: " + asgardeoUser.id);

    // Send the patch request to Asgardeo.
    http:Request request = new;
    request.setPayload(requestBody, "application/json");
    http:Response|error response = check asgardeoClient->patch("/scim2/Users/" + asgardeoUser.id, request);

    if response is error {
        log:printError(string `Error while changing password of the user: ${asgardeoUser.id}.`, response);
        return error("Error while changing the password.");
    }

    // Handle error.
    if response.statusCode != http:STATUS_OK {
        json|error jsonPayload = response.getJsonPayload();
        log:printError(string `Error while changing the password. 
            ${jsonPayload is json ? jsonPayload.toString() : response.statusCode}`);
        return error("Error while changing the password.");
    }
}
