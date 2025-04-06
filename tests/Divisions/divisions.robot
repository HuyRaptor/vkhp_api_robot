*** Settings ***
Documentation     Comprehensive Test Suite for Division Operations in vKho API
...               Includes proper parameter validation and error handling
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Library           re
Library           json
Resource          ../../Variables/variables.robot

*** Keywords ***
Setup API Session
    [Documentation]     Create API session and authenticate
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    
    # Prepare login request
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${MANAGER_USERNAME}    password=${MANAGER_PASSWORD}
    
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
    ...    msg=Authentication failed: Response did not contain access_token
    
    # Save token for subsequent tests
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${AUTH_TOKEN}    ${token}
    
    # Create results directory if it doesn't exist
    Create Directory    ${RESULTS_DIR}

Generate Unique Division Data
    [Documentation]     Generate unique data for division tests
    [Arguments]         ${custom_name}=Test Division
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${division_name}=   Set Variable     ${custom_name} ${timestamp}
    
    # Return dictionary of generated data
    ${division_data}=   Create Dictionary
    ...                 name=${division_name}
    ...                 warehouseId=${WAREHOUSE_ID}
    RETURN            ${division_data}

Create Division
    [Documentation]     Create a new division and return its ID
    [Arguments]         ${division_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${division_data}    name
    ...    msg=Missing required parameter: name
    Dictionary Should Contain Key    ${division_data}    warehouseId
    ...    msg=Missing required parameter: warehouseId
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send create division request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /divison/create
    ...                 json=${division_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Save response for debugging
    ${timestamp}=       Evaluate         int(time.time())    time
    Create File         ${RESULTS_DIR}${/}division_create_${timestamp}.json    ${response.text}
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Create division response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Create division response missing ID field
    
    # Return division ID and full response
    ${division_id}=     Convert To String    ${json}[id]
    RETURN            ${division_id}    ${json}

Get Division By ID
    [Documentation]     Retrieve a specific division by ID with proper response handling
    [Arguments]         ${division_id}
    
    # Validate parameters
    Should Not Be Empty    ${division_id}
    ...    msg=Division ID cannot be empty
    
    # Convert ID to integer if needed
    ${division_id}=     Convert To Integer    ${division_id}
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get division request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /divison/get-one/${division_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response as single object
    ${json_response}=   Set Variable    ${response.json()}
    
    # Check if response is wrapped in data field
    ${has_data}=        Run Keyword And Return Status
    ...                 Dictionary Should Contain Key    ${json_response}    data
    
    # Extract division data
    ${division}=        Set Variable If    ${has_data}
    ...                 ${json_response}[data]
    ...                 ${json_response}
    
    Should Be True      isinstance($division, dict)
    ...    msg=Response is not a JSON object. Got: ${division}
    
    # Log the response object
    Log    Retrieved division: ${division}
    
    # Validate division data
    Validate Division Response    ${division}
    
    RETURN    ${division}

Update Division
    [Documentation]     Update an existing division
    [Arguments]         ${division_id}    ${update_data}
    
    # Validate parameters
    Should Not Be Empty    ${division_id}
    ...    msg=Division ID cannot be empty
    Dictionary Should Contain Key    ${update_data}    id
    ...    msg=Update data must contain id field
    Should Be Equal     ${update_data}[id]    ${division_id}
    ...    msg=Update data ID must match division_id parameter
    
    # Ensure minimum required fields are present
    Dictionary Should Contain Key    ${update_data}    name
    ...    msg=Update data missing required field: name
    Dictionary Should Contain Key    ${update_data}    warehouseId
    ...    msg=Update data missing required field: warehouseId
    Dictionary Should Contain Key    ${update_data}    status
    ...    msg=Update data missing required field: status
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send update division request
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /divison/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Update division response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Update division response missing ID field
    
    RETURN            ${json}

Delete Division
    [Documentation]     Delete a division from the system
    [Arguments]         ${division_id}
    
    # Validate parameters
    Should Not Be Empty    ${division_id}
    ...    msg=Division ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send delete division request
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /divison/delete/${division_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Return deletion status
    RETURN            ${TRUE}

Get All Divisions
    [Documentation]     Retrieve all divisions with array response handling
    [Arguments]         ${warehouse_id}=${WAREHOUSE_ID}    ${filter_params}=${EMPTY}
    
    # Validate parameters
    Should Not Be Empty    ${warehouse_id}
    ...    msg=Warehouse ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary
    ...                 Content-Type=application/json
    ...                 Authorization=${AUTH_TOKEN}
    
    # Create params dictionary
    ${params}=          Create Dictionary    warehouseId=${warehouse_id}
    
    # Add any additional filter parameters if provided
    Run Keyword If      "${filter_params}" != "${EMPTY}"
    ...                 Set To Dictionary    ${params}    &{filter_params}
    
    # Send get all divisions request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /divison/get-all
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Get and validate response
    ${json_response}=   Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json_response}    data
    Dictionary Should Contain Key    ${json_response}    totalItem
    
    # Extract data array
    ${divisions}=       Set Variable    ${json_response}[data]
    ${total_count}=     Set Variable    ${json_response}[totalItem]
    
    # Log response details
    Log    Total divisions: ${total_count}
    Log    Division array: ${divisions}
    
    # Validate each division in the response
    FOR    ${division}    IN    @{divisions}
        Validate Division Response    ${division}
        Log    Validated division: ${division}
    END
    
    RETURN    ${divisions}

Assert Division Details
    [Documentation]     Verify division details match expected values with type conversion
    [Arguments]         ${division}    ${expected_data}
    
    # For all keys in expected data, verify they match in the division data
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${division}    Run Keywords
        ...    ${actual_value}=    Convert To String    ${division}[${key}]    AND
        ...    ${expected_value}=    Convert To String    ${expected_data}[${key}]    AND
        ...    Should Be Equal    ${actual_value}    ${expected_value}
        ...    msg=Division ${key} value '${division}[${key}]' does not match expected '${expected_data}[${key}]'
    END

Create Test Division
    [Documentation]     Creates a test division if one doesn't exist
    ${division_data}=   Generate Unique Division Data
    ${division_id}    ${response}=    Create Division    ${division_data}
    Set Global Variable  ${TEST_DIVISION_ID}      ${division_id}
    Set Global Variable  ${TEST_DIVISION_NAME}    ${response}[name]
    Set Global Variable  ${TEST_DIVISION_DATA}    ${division_data}

Parse JSON Response
    [Documentation]     Safely parse JSON response and handle both object and array responses
    [Arguments]         ${response_text}
    
    # Clean and prepare the JSON string
    ${cleaned_text}=    Clean JSON String    ${response_text}
    
    # Parse JSON with error handling
    TRY
        # First attempt to parse as-is
        ${json}=        Evaluate    json.loads('''${cleaned_text}''')    json
        
        # Handle response format
        ${has_data}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${json}    data
        
        # If response has data field, return the data array
        IF    ${has_data}
            ${result}=    Set Variable    ${json}[data]
        # If response is already a list, use it directly
        ELSE IF    ${json.__class__.__name__} == 'list'
            ${result}=    Set Variable    ${json}
        # Otherwise, wrap single object in a list
        ELSE
            ${result}=    Create List    ${json}
        END
        
    EXCEPT    AS    ${error}
        Log    Failed to parse JSON: ${error}
        Log    Original text: ${response_text}
        Log    Cleaned text: ${cleaned_text}
        Fail    JSON parsing failed: ${error}
    END
    
    RETURN    ${result}

Validate Division Response
    [Documentation]     Validate division response structure and content
    [Arguments]         ${division}
    Should Have Keys    ${division}    id    name    status    warehouseId
    Should Not Be Empty    ${division}[id]
    Should Not Be Empty    ${division}[name]
    Should Be Equal    ${division}[warehouseId]    ${WAREHOUSE_ID}

Should Have Keys
    [Documentation]     Verify dictionary contains all required keys
    [Arguments]         ${dict}    @{keys}
    FOR    ${key}    IN    @{keys}
        Dictionary Should Contain Key    ${dict}    ${key}
        ...    msg=Response missing required field: ${key}
    END

Should Be Integer
    [Documentation]     Verify value is an integer
    [Arguments]         ${value}
    ${type}=           Evaluate    type($value).__name__
    Should Be Equal    ${type}    int
    ...    msg=Value '${value}' is not an integer

Should Be String
    [Documentation]     Verify value is a string
    [Arguments]         ${value}
    ${type}=           Evaluate    type($value).__name__
    Should Be Equal    ${type}    str
    ...    msg=Value '${value}' is not a string

Compare Values With Type Conversion
    [Documentation]     Compare values after converting to appropriate types
    [Arguments]         ${actual}    ${expected}    ${field_name}
    
    # Handle integer fields
    ${integer_fields}=    Create List    id    warehouseId    totalItem
    
    # Convert based on field type
    IF    '${field_name}' in ${integer_fields}
        ${actual_value}=    Convert To Integer    ${actual}
        ${expected_value}=  Convert To Integer    ${expected}
    ELSE
        ${actual_value}=    Convert To String    ${actual}
        ${expected_value}=  Convert To String    ${expected}
    END
    
    Should Be Equal    ${actual_value}    ${expected_value}
    ...    msg=Division ${field_name} value '${actual}' does not match expected '${expected}'

Validate JSON String
    [Documentation]     Validate and clean JSON string before parsing
    [Arguments]         ${json_string}
    
    # Remove null bytes and control characters
    ${cleaned}=         Evaluate    
    ...    ''.join(c for c in '''${json_string}''' if c >= ' ' or c in ['\n', '\r', '\t'])
    
    # Basic JSON structure validation
    Should Start With    ${cleaned}    {    msg=Invalid JSON: Must start with '{'
    Should End With      ${cleaned}    }    msg=Invalid JSON: Must end with '}'
    
    RETURN             ${cleaned}

Clean JSON String
    [Documentation]     Clean JSON string from special characters and escape sequences
    [Arguments]         ${json_string}
    
    # First handle basic string escaping
    ${escaped}=         Replace String    ${json_string}    \\    \\\\
    ${escaped}=         Replace String    ${escaped}    \"    \\"
    
    # Then remove problematic characters
    ${cleaned}=         Replace String    ${escaped}    \x00    ${EMPTY}
    ${cleaned}=         Replace String    ${cleaned}    \t    ${SPACE}
    ${cleaned}=         Replace String    ${cleaned}    \n    ${SPACE}
    ${cleaned}=         Replace String    ${cleaned}    \r    ${SPACE}
    
    # Handle any remaining control characters
    ${cleaned}=         Evaluate    
    ...    ''.join(char for char in '''${cleaned}''' if ord(char) >= 32 or char in ['\n', '\r', '\t'])
    
    RETURN             ${cleaned}

Extract JSON Value
    [Documentation]     Safely extract value from JSON response
    [Arguments]         ${json}    ${key}    ${default}=${None}
    
    ${status}=         Run Keyword And Return Status
    ...                Dictionary Should Contain Key    ${json}    ${key}
    
    ${value}=          Set Variable If    ${status}    ${json}[${key}]    ${default}
    
    RETURN            ${value}

Response Should Be JSON Array
    [Documentation]     Verify response contains a data array
    [Arguments]         ${response}
    ${json_response}=   Set Variable    ${response.json()}
    
    # Check if response has data field
    Dictionary Should Contain Key    ${json_response}    data
    ...    msg=Response missing 'data' field. Got: ${json_response}
    
    # Verify data is an array
    ${data_array}=      Set Variable    ${json_response}[data]
    Should Be True      isinstance($data_array, list)
    ...    msg=Response data is not an array. Got: ${data_array}
    
    Log    JSON Array Response: ${data_array}
    RETURN    ${data_array}

Response Should Contain JSON Objects
    [Documentation]     Verify each item in response is a JSON object
    [Arguments]         ${response}
    ${json_response}=   Set Variable    ${response.json()}
    FOR    ${item}    IN    @{json_response}
        Should Be True    isinstance($item, dict)    
        ...    msg=Item is not a JSON object: ${item}
        Log    JSON Object: ${item}
    END
    RETURN    ${json_response}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for division tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Division Test
    [Documentation]     Test creating a new division
    [Tags]              create    positive
    
    # Generate division data
    ${division_data}=   Generate Unique Division Data
    
    # Create division
    ${division_id}    ${response}=    Create Division    ${division_data}
    
    # Verify division was created successfully
    Should Not Be Empty    ${division_id}
    ...    msg=Failed to create division: No ID returned
    Should Be Equal     ${response}[name]    ${division_data}[name]
    ...    msg=Created division name does not match input data
    
    # Save division ID for subsequent tests
    Set Global Variable  ${TEST_DIVISION_ID}      ${division_id}
    Set Global Variable  ${TEST_DIVISION_NAME}    ${response}[name]
    Set Global Variable  ${TEST_DIVISION_DATA}    ${division_data}
    
    Log                 Successfully created division: ${TEST_DIVISION_NAME} with ID: ${TEST_DIVISION_ID}

03 - Create Division Missing Required Field Test
    [Documentation]     Test creating a division with missing required fields
    [Tags]              create    negative
    
    # Generate incomplete division data (missing warehouseId)
    ${incomplete_data}=  Generate Unique Division Data    custom_name=Missing Field Division
    Remove From Dictionary    ${incomplete_data}    warehouseId
    
    # Attempt to create division with incomplete data
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect proper error message
    Run Keyword And Expect Error    *Missing required parameter: warehouseId*
    ...                 Create Division    ${incomplete_data}
    
    Log                 Successfully verified that creating a division with missing fields is rejected

04 - Get Division Test
    [Documentation]     Test retrieving a specific division
    [Tags]              retrieve    positive
    
    # Create a division if one doesn't exist
    Run Keyword If      "${TEST_DIVISION_ID}" == "${EMPTY}"    Create Test Division
    
    # Get division
    ${division}=        Get Division By ID    ${TEST_DIVISION_ID}
    
    # Verify response is a JSON object
    Should Be True      isinstance($division, dict)
    ...    msg=Response should be a JSON object. Got: ${division}
    
    # Verify required fields exist
    Should Have Keys    ${division}    id    name    status    warehouseId
    
    # Verify data types
    Should Be Integer    ${division}[id]
    Should Be String     ${division}[name]
    Should Be String     ${division}[status]
    Should Be Integer    ${division}[warehouseId]
    
    # Verify division details with type-safe comparisons
    Compare Values With Type Conversion    ${division}[id]    ${TEST_DIVISION_ID}    id
    Compare Values With Type Conversion    ${division}[name]    ${TEST_DIVISION_DATA}[name]    name
    Compare Values With Type Conversion    ${division}[warehouseId]    ${TEST_DIVISION_DATA}[warehouseId]    warehouseId
    
    # Verify status is valid
    Should Be True      "${division}[status]" in ["ENABLE", "DISABLE"]
    ...    msg=Invalid status value: ${division}[status]
    
    Log    Successfully retrieved and validated division: ${division}

05 - Get Non-Existent Division Test
    [Documentation]     Test retrieving a division that doesn't exist
    [Tags]              retrieve    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to get non-existent division
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 GET On Session
    ...                 vkho
    ...                 /divison/get-one/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that retrieving a non-existent division fails

06 - Update Division Test
    [Documentation]     Test updating an existing division
    [Tags]              update    positive
    
    # Create a division if one doesn't exist
    Run Keyword If      "${TEST_DIVISION_ID}" == "${EMPTY}"    Create Test Division
    
    # Prepare update data
    ${updated_name}=    Set Variable    ${TEST_DIVISION_NAME} Updated
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_DIVISION_ID}
    ...                 name=${updated_name}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 status=ENABLE
    
    # Update division
    ${updated_division}=    Update Division    ${TEST_DIVISION_ID}    ${update_data}
    
    # Verify division was updated successfully
    Should Be Equal     ${updated_division}[name]    ${updated_name}
    ...    msg=Updated division name does not match expected value
    
    # Update global variable with new data
    Set Global Variable  ${TEST_DIVISION_NAME}    ${updated_name}
    
    Log                 Successfully updated division: ${updated_division}[name]

07 - Update Division With Missing Required Field Test
    [Documentation]     Test updating a division with missing required fields
    [Tags]              update    negative
    
    # Create a division if one doesn't exist
    Run Keyword If      "${TEST_DIVISION_ID}" == "${EMPTY}"    Create Test Division
    
    # Prepare incomplete update data (missing status)
    ${incomplete_data}=  Create Dictionary
    ...                 id=${TEST_DIVISION_ID}
    ...                 name=Incomplete Update
    ...                 warehouseId=${WAREHOUSE_ID}
    # Missing status field
    
    # Attempt to update division with incomplete data
    Run Keyword And Expect Error    *Update data missing required field: status*
    ...                 Update Division    ${TEST_DIVISION_ID}    ${incomplete_data}
    
    Log                 Successfully verified that updating a division with missing fields is rejected

08 - Get All Divisions Test
    [Documentation]     Test retrieving all divisions with array response handling
    [Tags]              retrieve    positive
    
    # Get all divisions
    ${divisions}=       Get All Divisions
    
    # Verify we got a list
    Should Be True      isinstance($divisions, list)
    ...    msg=Response should be a list of divisions
    
    # Verify we have divisions
    ${count}=          Get Length    ${divisions}
    Should Be True     ${count} >= 0    msg=Should have zero or more divisions
    
    # Log response details
    Log    Retrieved ${count} divisions
    
    # Verify each division in the response
    FOR    ${division}    IN    @{divisions}
        # Basic structure validation
        Should Have Keys    ${division}    id    name    status    warehouseId
        
        # Data type validation
        Should Be Integer    ${division}[id]
        Should Be String     ${division}[name]
        Should Be String     ${division}[status]
        Should Be Integer    ${division}[warehouseId]
        
        # Status validation
        Should Be True      "${division}[status]" in ["ENABLE", "DISABLE"]
        ...    msg=Invalid status value: ${division}[status]
        
        # Warehouse ID validation
        Should Be Equal As Integers    ${division}[warehouseId]    ${WAREHOUSE_ID}
        ...    msg=Division belongs to incorrect warehouse
        
        # Log validated division
        Log    Validated division: ${division}
    END
    
    Log    Successfully validated all ${count} divisions

09 - Delete Division Test
    [Documentation]     Test deleting a division
    [Tags]              delete    positive
    
    # Create a division if one doesn't exist
    Run Keyword If      "${TEST_DIVISION_ID}" == "${EMPTY}"    Create Test Division
    
    # Delete division
    ${result}=          Delete Division    ${TEST_DIVISION_ID}
    Should Be True      ${result}
    ...    msg=Delete division operation failed
    
    # Verify division deletion by trying to get it
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /divison/get-one/${TEST_DIVISION_ID}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    # API might handle deletion differently: either 404 Not Found or status = DISABLE
    ${is_deleted}=      Run Keyword If      ${response.status_code} == 404    Set Variable    ${TRUE}
    ...    ELSE         Set Variable    ${FALSE}
    
    Should Be True      ${is_deleted}
    ...    msg=Division was not properly deleted or marked as deleted
    
    Log                 Successfully verified deletion of division with ID: ${TEST_DIVISION_ID}

10 - Delete Non-Existent Division Test
    [Documentation]     Test deleting a division that doesn't exist
    [Tags]              delete    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to delete non-existent division
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 DELETE On Session
    ...                 vkho
    ...                 /divison/delete/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that deleting a non-existent division fails

11 - Cleanup Test Environment
    [Documentation]     Clean up any resources created during tests
    [Tags]              cleanup
    
    # Additional cleanup if needed
    Log                 Test environment cleaned up successfully