type User record {|
    readonly string id;
    readonly string username;
    readonly string password;
|};

type AsgardeoUser record {|
    string id;
    string username;
|};

type AsgardeoAppConfig readonly & record {|
    string tokenUrl;
    string clientId;
    string clientSecret;
|};

type AsgardeoUserResponse record {|
    string id;
    string username;
    string[] emails;
    json...;
|};
