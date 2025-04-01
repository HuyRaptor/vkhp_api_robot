*** Settings ***
Documentation     Advanced Test Suite for User Operations in vKho API
...               Includes complex scenarios like bulk operations, dependencies, concurrency, pagination, and edge cases
...               Assumes typical user management endpoints based on auth patterns
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Library           BuiltIn

*** Variables ***
${BASE_URL}             https://api.vkho.net
${ADMIN_USERNAME}       huynh22
${ADMIN_PASSWORD}       Snowfox1991
${RESULTS_DIR}          ${CURDIR}${/}results
${TEST_USER_ID}         ${EMPTY}
${TEST_USERNAME}        ${EMPTY}
${TEST_USER_DATA}       ${EMPTY}
${BULK_USER_IDS}        ${EMPTY}
${AUTH_TOKEN}           ${EMPTY}

*** Keywords ***
Setup API Session
    [Documentation]     Create API session and authenticate as admin
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    
    # Prepare admin login request
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${ADMIN_USERNAME}    password=${ADMIN_PASSWORD}
    
    # Send login request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /auth/login
    ...                 json=${body}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    access_token
    ...    msg=Admin authentication failed: Response did not contain access_token
    
    # Save token for subsequent tests
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${AUTH_TOKEN}    ${token}
    
    # Create results directory if it doesn’t exist
    Create Directory    ${RESULTS_DIR}

Generate Unique User Data
    [Documentation]     Generate unique data for user tests
    [Arguments]         ${custom_username}=testuser    ${role}=USER
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${username}=        Set Variable     ${custom_username}${timestamp}
    
    # Base user data
    ${user_data}=       Create Dictionary
    ...                 username=${username}
    ...                 password=Password${timestamp}!
    ...                 email=${username}@example.com
    ...                 fullName=Test User ${timestamp}
    ...                 role=${role}
    
    [Return]            ${user_data}

Create User
    [Documentation]     Create a new user and return its ID
    [Arguments]         ${user_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${user_data}    username
    ...    msg=Missing required parameter: username
    Dictionary Should Contain Key    ${user_data}    password
    ...    msg=Missing required parameter: password
    Dictionary Should Contain Key    ${user_data}    role
    ...    msg=Missing required parameter: role
    
    # Prepare request (assuming /users/create endpoint)
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send create user request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /users/create
    ...                 json=${user_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Create user response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Create user response missing ID field
    
    # Return user ID and full response
    ${user_id}=         Convert To String    ${json}[id]
    [Return]            ${user_id}    ${json}

Get User By ID
    [Documentation]     Retrieve a specific user by ID
    [Arguments]         ${user_id}
    
    # Validate parameters
    Should Not Be Empty    ${user_id}
    ...    msg=User ID cannot be empty
    
    # Prepare request (assuming /users/get-one/{id} endpoint)
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get user request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /users/get-one/${user_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get user response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Get user response missing ID field
    
    [Return]            ${json}

Update User
    [Documentation]     Update an existing user
    [Arguments]         ${user_id}    ${update_data}
    
    # Validate parameters
    Should Not Be Empty    ${user_id}
    ...    msg=User ID cannot be empty
    Dictionary Should Contain Key    ${update_data}    id
    ...    msg=Update data must contain id field
    Should Be Equal     ${update_data}[id]    ${user_id}
    ...    msg=Update data ID must match user_id parameter
    
    # Ensure minimum required fields are present
    Dictionary Should Contain Key    ${update_data}    username
    ...    msg=Update data missing required field: username
    Dictionary Should Contain Key    ${update_data}    role
    ...    msg=Update data missing required field: role
    
    # Prepare request (assuming /users/update endpoint)
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send update user request
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /users/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Update user response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Update user response missing ID field
    
    [Return]            ${json}

Delete User
    [Documentation]     Delete a user from the system
    [Arguments]         ${user_id}
    
    # Validate parameters
    Should Not Be Empty    ${user_id}
    ...    msg=User ID cannot be empty
    
    # Prepare request (assuming /users/delete/{id} endpoint)
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send delete user request
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /users/delete/${user_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Return deletion status
    [Return]            ${TRUE}

Get All Users
    [Documentation]     Retrieve all users with filtering, pagination, and sorting
    [Arguments]         ${filter_params}=${EMPTY}    ${page}=${EMPTY}    ${limit}=${EMPTY}    ${sort}=${EMPTY}
    
    # Prepare request (assuming /users/get-all endpoint)
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Create params dictionary
    ${params}=          Create Dictionary
    Run Keyword If      "${filter_params}" != "${EMPTY}"    Set To Dictionary    ${params}    &{filter_params}
    Run Keyword If      "${page}" != "${EMPTY}"             Set To Dictionary    ${params}    page=${page}
    Run Keyword If      "${limit}" != "${EMPTY}"            Set To Dictionary    ${params}    limit=${limit}
    Run Keyword If      "${sort}" != "${EMPTY}"             Set To Dictionary    ${params}    sort=${sort}
    
    # Send get all users request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /users/get-all
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get all users response was empty
    
    [Return]            ${json}

Authenticate User
    [Documentation]     Authenticate a user and return their token
    [Arguments]         ${username}    ${password}
    
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${username}    password=${password}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /auth/login
    ...                 json=${body}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${token}=           Set Variable     Bearer ${json}[access_token]
    [Return]            ${token}

Bulk Create Users
    [Documentation]     Create multiple users in bulk with validation
    [Arguments]         ${count}=5
    
    ${user_ids}=        Create List
    FOR    ${i}    IN RANGE    ${count}
        ${role}=        Set Variable    ${"USER" if ${i} % 2 == 0 else "MANAGER"}
        ${user_data}=   Generate Unique User Data    custom_username=bulkuser${i}    role=${role}
        ${user_id}    ${response}=    Create User    ${user_data}
        Append To List  ${user_ids}    ${user_id}
    END
    [Return]            ${user_ids}

Assert User Details
    [Documentation]     Verify user details match expected values
    [Arguments]         ${user}    ${expected_data}
    
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${user} and "${key}" != "password"
        ...               Should Be Equal    ${user}[${key}]    ${expected_data}[${key}]
        ...               msg=User ${key} value '${user}[${key}]' does not match expected '${expected_data}[${key}]'
    END

Create Test User
    [Documentation]     Creates a test user if one doesn’t exist
    ${user_data}=       Generate Unique User Data    role=USER
    ${user_id}    ${response}=    Create User    ${user_data}
    Set Global Variable  ${TEST_USER_ID}      ${user_id}
    Set Global Variable  ${TEST_USERNAME}     ${response}[username]
    Set Global Variable  ${TEST_USER_DATA}    ${user_data}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for complex user tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated as admin with token: ${AUTH_TOKEN}

02 - Bulk User Creation With Role Assignment Test
    [Documentation]     Test creating multiple users in bulk with varying roles
    [Tags]              create    bulk    positive
    
    ${bulk_ids}=        Bulk Create Users    count=5
    Should Not Be Empty    ${bulk_ids}
    ...    msg=Failed to create bulk users: No IDs returned
    Should Be Equal As Integers    ${bulk_ids.__len__()}    5
    ...    msg=Expected 5 users, but created ${bulk_ids.__len__()}
    
    # Verify each user exists and has correct role
    FOR    ${id}    IN    @{bulk_ids}
        ${user}=        Get User By ID    ${id}
        Should Not Be Empty    ${user}
        ...    msg=User ${id} from bulk creation not found
        Should Be True    "${user}[role]" in ["USER", "MANAGER"]
        ...    msg=User ${id} has invalid role: ${user}[role]
    END
    
    Set Global Variable  ${BULK_USER_IDS}    ${bulk_ids}
    Log                 Successfully created and validated ${bulk_ids.__len__()} users: ${bulk_ids}

03 - Create User With Duplicate Username Test
    [Documentation]     Test creating a user with a duplicate username
    [Tags]              create    negative
    
    # Create first user
    ${user_data}=       Generate Unique User Data    custom_username=duplicateuser
    ${user_id}    ${response}=    Create User    ${user_data}
    
    # Attempt to create second user with same username
    ${duplicate_data}=  Create Dictionary    &{user_data}
    Set To Dictionary   ${duplicate_data}    email=duplicate2@example.com
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /users/create
    ...                 json=${duplicate_data}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    Should Not Equal As Integers    ${response.status_code}    201
    ...    msg=API allowed creation of user with duplicate username
    Log                 Successfully verified duplicate username rejection: ${response.text}

04 - User Authentication Dependency Test
    [Documentation]     Test creating a user and verifying authentication
    [Tags]              create    dependency    positive
    
    # Create user
    ${user_data}=       Generate Unique User Data    custom_username=authuser    role=USER
    ${user_id}    ${response}=    Create User    ${user_data}
    
    # Authenticate user
    ${user_token}=      Authenticate User    ${user_data}[username]    ${user_data}[password]
    Should Not Be Empty    ${user_token}
    ...    msg=Failed to authenticate created user
    
    # Retrieve and verify user details
    ${user}=            Get User By ID    ${user_id}
    Assert User Details    ${user}    ${user_data}
    
    Log                 Successfully created user ${user_id} and verified authentication

05 - Concurrent User Role Updates Test
    [Documentation]     Test concurrent role updates to a user
    [Tags]              update    concurrent    positive
    
    # Create user
    ${user_data}=       Generate Unique User Data    custom_username=concurrentuser    role=USER
    ${user_id}    ${response}=    Create User    ${user_data}
    
    # First update: Role to MANAGER
    ${update_data_1}=   Create Dictionary
    ...                 id=${user_id}
    ...                 username=${user_data}[username]
    ...                 password=${user_data}[password]
    ...                 email=${user_data}[email]
    ...                 fullName=${user_data}[fullName]
    ...                 role=MANAGER
    ${updated_1}=       Update User    ${user_id}    ${update_data_1}
    
    # Second update: Role to ADMIN (simulating concurrent change)
    ${update_data_2}=   Create Dictionary    &{update_data_1}
    Set To Dictionary   ${update_data_2}    role=ADMIN
    ${updated_2}=       Update User    ${user_id}    ${update_data_2}
    
    # Verify final state
    ${final_user}=      Get User By ID    ${user_id}
    Should Be Equal     ${final_user}[role]    ADMIN
    ...    msg=Second concurrent update did not apply correctly
    
    Log                 Successfully verified concurrent role updates on user ${user_id}

06 - Pagination And Role Filtering Users Test
    [Documentation]     Test retrieving users with pagination and role filter
    [Tags]              retrieve    pagination    filter    positive
    
    # Ensure bulk users exist
    Run Keyword If      "${BULK_USER_IDS}" == "${EMPTY}"    Bulk Create Users    count=10
    
    # Filter by role=USER, paginate (page 1, limit 4)
    ${filter_params}=   Create Dictionary    role=USER
    ${users_page_1}=    Get All Users    filter_params=${filter_params}    page=1    limit=4
    
    # Verify response structure
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${users_page_1}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${users_page_1}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${users_page_1}    records
    
    ${items}=           Set Variable    ${EMPTY}
    IF    ${has_data}
        ${items}=       Set Variable    ${users_page_1}[data]
    ELSE IF    ${has_items}
        ${items}=       Set Variable    ${users_page_1}[items]
    ELSE IF    ${has_records}
        ${items}=       Set Variable    ${users_page_1}[records]
    END
    
    Should Not Be Empty    ${items}
    ...    msg=Paginated users response was empty
    Should Be True         ${items.__len__()} <= 4
    ...    msg=Page 1 exceeded limit of 4 items: ${items.__len__()}
    
    # Verify all items match filter
    FOR    ${item}    IN    @{items}
        Should Be Equal    ${item}[role]    USER
        ...    msg=User ${item['id']} role ${item['role']} does not match filter
    END
    
    Log                 Successfully retrieved paginated and filtered users: ${items.__len__()} items

07 - Delete User With Active Session Test
    [Documentation]     Test deleting a user with an active authenticated session
    [Tags]              delete    dependency    negative
    
    # Create user
    ${user_data}=       Generate Unique User Data    custom_username=sessionuser    role=USER
    ${user_id}    ${response}=    Create User    ${user_data}
    
    # Authenticate user to create an active session
    ${user_token}=      Authenticate User    ${user_data}[username]    ${user_data}[password]
    
    # Attempt to delete user with active session
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /users/delete/${user_id}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    # Expect failure if API enforces session dependency (assumption)
    Should Not Equal As Integers    ${response.status_code}    200
    ...    msg=API allowed deletion of user with active session
    Log                 Successfully verified rejection of user deletion with active session

08 - Edge Case - User With Malformed Email Test
    [Documentation]     Test creating a user with a malformed email
    [Tags]              create    edge    negative
    
    ${user_data}=       Generate Unique User Data    custom_username=malformedemailuser
    Set To Dictionary   ${user_data}    email=invalid-email-format
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /users/create
    ...                 json=${user_data}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    Should Not Equal As Integers    ${response.status_code}    201
    ...    msg=API allowed creation of user with malformed email
    Log                 Successfully verified rejection of user with malformed email: ${response.text}

09 - Edge Case - User With Maximum Length Fields Test
    [Documentation]     Test creating a user with maximum length field values
    [Tags]              create    edge    positive
    
    ${long_username}=   Set Variable    ${"u" * 50}    # Assuming 50 char limit
    ${long_fullname}=   Set Variable    ${"A" * 255}   # Assuming 255 char limit
    
    ${user_data}=       Create Dictionary
    ...                 username=${long_username}
    ...                 password=Password123!
    ...                 email=${long_username}@example.com
    ...                 fullName=${long_fullname}
    ...                 role=USER
    
    ${user_id}    ${response}=    Create User    ${user_data}
    Should Not Be Empty    ${user_id}
    ...    msg=Failed to create user with max length fields
    
    ${user}=            Get User By ID    ${user_id}
    Should Be Equal     ${user}[username]    ${long_username}
    ...    msg=Created user username does not match max length input
    Should Be Equal     ${user}[fullName]    ${long_fullname}
    ...    msg=Created user fullName does not match max length input
    Log                 Successfully created user with maximum length fields: ${user_id}

10 - Cleanup Test Environment
    [Documentation]     Clean up resources created during complex tests
    [Tags]              cleanup
    
    # Clean up bulk users
    Run Keyword If      "${BULK_USER_IDS}" != "${EMPTY}"
    ...                 Run Keywords
    ...                 FOR    ${id}    IN    @{BULK_USER_IDS}
    ...                 Delete User    ${id}
    ...                 END
    ...                 AND    Set Global Variable    ${BULK_USER_IDS}    ${EMPTY}
    
    # Clean up test user
    Run Keyword If      "${TEST_USER_ID}" != "${EMPTY}"
    ...                 Delete User    ${TEST_USER_ID}
    ...                 AND    Set Global Variable    ${TEST_USER_ID}    ${EMPTY}
    
    Log                 Test environment cleaned up successfully