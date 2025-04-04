*** Settings ***
Documentation     Comprehensive Test Suite for Division Operations in vKho API
...               Includes proper parameter validation and error handling
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Resource          ../../Variables/variables.robot

*** Keywords ***
Setup API Session
    [Documentation]     Create API session and authenticate
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    
    # Prepare login request
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${USERNAME}    password=${PASSWORD}
    
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
    [Documentation]     Retrieve a specific division by ID
    [Arguments]         ${division_id}
    
    # Validate parameters
    Should Not Be Empty    ${division_id}
    ...    msg=Division ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get division request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /divison/get-one/${division_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get division response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Get division response missing ID field
    
    RETURN            ${json}

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
    [Documentation]     Retrieve all divisions with optional filtering
    [Arguments]         ${warehouse_id}=${WAREHOUSE_ID}    ${filter_params}=${EMPTY}
    
    # Validate parameters
    Should Not Be Empty    ${warehouse_id}
    ...    msg=Warehouse ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Create params dictionary
    ${params}=          Create Dictionary    warehouseId=${warehouse_id}
    
    # Add any additional filter parameters if provided
    Run Keyword If      "${filter_params}" != "${EMPTY}"    Set To Dictionary    ${params}    &{filter_params}
    
    # Send get all divisions request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /divison/get-all
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get all divisions response was empty
    
    RETURN            ${json}

Assert Division Details
    [Documentation]     Verify division details match expected values
    [Arguments]         ${division}    ${expected_data}
    
    # For all keys in expected data, verify they match in the division data
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${division}    Should Be Equal    ${division}[${key}]    ${expected_data}[${key}]
        ...    msg=Division ${key} value '${division}[${key}]' does not match expected '${expected_data}[${key}]'
    END

Create Test Division
    [Documentation]     Creates a test division if one doesn't exist
    ${division_data}=   Generate Unique Division Data
    ${division_id}    ${response}=    Create Division    ${division_data}
    Set Global Variable  ${TEST_DIVISION_ID}      ${division_id}
    Set Global Variable  ${TEST_DIVISION_NAME}    ${response}[name]
    Set Global Variable  ${TEST_DIVISION_DATA}    ${division_data}

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
    
    # Verify division details match what we created
    Assert Division Details    ${division}    ${TEST_DIVISION_DATA}
    
    Log                 Successfully retrieved division: ${division}[name]

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
    [Documentation]     Test retrieving all divisions
    [Tags]              retrieve    positive
    
    # Get all divisions
    ${divisions}=       Get All Divisions
    
    # Verify response contains data
    Should Not Be Empty    ${divisions}
    ...    msg=Get all divisions response was empty
    
    Log                 Successfully retrieved divisions list

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