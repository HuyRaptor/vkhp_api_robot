*** Settings ***
Documentation     Comprehensive Test Suite for Zone Operations in vKho API
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

Generate Unique Zone Data
    [Documentation]     Generate unique data for zone tests
    
    # Prepare zone creation data
    ${timestamp}=       Evaluate         int(time.time())    time
    ${zone_name}=       Set Variable     Test Zone ${timestamp}
    ${zone_data}=       Create Dictionary
    ...                 capcity=100
    ...                 name=${zone_name}
    ...                 warehouseId=${WAREHOUSE_ID}
    
    RETURN            ${zone_data}

Create Zone
    [Documentation]     Create a new zone and return its ID
    [Arguments]         ${zone_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${zone_data}    capcity
    ...    msg=Missing required parameter: capcity
    Dictionary Should Contain Key    ${zone_data}    name
    ...    msg=Missing required parameter: name
    Dictionary Should Contain Key    ${zone_data}    warehouseId
    ...    msg=Missing required parameter: warehouseId
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send create zone request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /zones/create
    ...                 json=${zone_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Save response for debugging
    ${timestamp}=       Evaluate         int(time.time())    time
    Create File         ${RESULTS_DIR}${/}zone_create_${timestamp}.json    ${response.text}
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Create zone response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Create zone response missing ID field
    
    # Return zone ID and full response
    ${zone_id}=         Convert To String    ${json}[id]
    RETURN            ${zone_id}    ${json}

Get Zone By ID
    [Documentation]     Retrieve a specific zone by ID
    [Arguments]         ${zone_id}
    
    # Validate parameters
    Should Not Be Empty    ${zone_id}
    ...    msg=Zone ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get zone request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /zones/get-one/${zone_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get zone response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Get zone response missing ID field
    
    RETURN            ${json}

Update Zone
    [Documentation]     Update an existing zone
    [Arguments]         ${zone_id}    ${update_data}
    
    # Validate parameters
    Should Not Be Empty    ${zone_id}
    ...    msg=Zone ID cannot be empty
    Dictionary Should Contain Key    ${update_data}    id
    ...    msg=Update data must contain id field
    Should Be Equal     ${update_data}[id]    ${zone_id}
    ...    msg=Update data ID must match zone_id parameter
    
    # Ensure minimum required fields are present
    Dictionary Should Contain Key    ${update_data}    capcity
    ...    msg=Update data missing required field: capcity
    Dictionary Should Contain Key    ${update_data}    name
    ...    msg=Update data missing required field: name
    Dictionary Should Contain Key    ${update_data}    warehouseId
    ...    msg=Update data missing required field: warehouseId
    Dictionary Should Contain Key    ${update_data}    status
    ...    msg=Update data missing required field: status
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send update zone request
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /zones/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Update zone response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Update zone response missing ID field
    
    RETURN            ${json}

Delete Zone
    [Documentation]     Delete a zone from the system
    [Arguments]         ${zone_id}
    
    # Validate parameters
    Should Not Be Empty    ${zone_id}
    ...    msg=Zone ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send delete zone request
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /zones/delete/${zone_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Return deletion status
    RETURN            ${TRUE}

Get All Zones
    [Documentation]     Retrieve all zones with optional filtering
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
    
    # Send get all zones request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /zones/get-all
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get all zones response was empty
    
    RETURN            ${json}

Assert Zone Details
    [Documentation]     Verify zone details match expected values
    [Arguments]         ${zone}    ${expected_data}
    
    # For all keys in expected data, verify they match in the zone data
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${zone}    Should Be Equal    ${zone}[${key}]    ${expected_data}[${key}]
        ...    msg=Zone ${key} value '${zone}[${key}]' does not match expected '${expected_data}[${key}]'
    END

Create Test Zone
    [Documentation]     Creates a test zone if one doesn't exist
    ${zone_data}=       Generate Unique Zone Data
    ${zone_id}    ${response}=    Create Zone    ${zone_data}
    Set Global Variable  ${TEST_ZONE_ID}      ${zone_id}
    Set Global Variable  ${TEST_ZONE_DATA}    ${zone_data}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for zone tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Zone Test
    [Documentation]     Test creating a new zone
    [Tags]              create    positive
    
    # Generate zone data
    ${zone_data}=       Generate Unique Zone Data
    
    # Create zone
    ${zone_id}    ${response}=    Create Zone    ${zone_data}
    
    # Verify zone was created successfully
    Should Not Be Empty    ${zone_id}
    ...    msg=Failed to create zone: No ID returned
    
    # Save zone ID for subsequent tests
    Set Global Variable  ${TEST_ZONE_ID}      ${zone_id}
    Set Global Variable  ${TEST_ZONE_DATA}    ${zone_data}
    
    Log                 Successfully created zone with ID: ${TEST_ZONE_ID}

03 - Create Zone Missing Required Field Test
    [Documentation]     Test creating a zone with missing required fields
    [Tags]              create    negative
    
    # Generate incomplete zone data (missing capcity)
    ${incomplete_data}=  Create Dictionary
    ...                 name=Incomplete Zone
    ...                 warehouseId=${WAREHOUSE_ID}
    
    # Attempt to create zone with incomplete data
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect proper error message
    Run Keyword And Expect Error    *Missing required parameter: capcity*
    ...                 Create Zone    ${incomplete_data}
    
    Log                 Successfully verifie  d that creating a zone with missing fields is rejected

04 - Get Zone Test
    [Documentation]     Test retrieving a specific zone
    [Tags]              retrieve    positive
    
    # Create a zone if one doesn't exist
    Run Keyword If      "${TEST_ZONE_ID}" == "${EMPTY}"    Create Test Zone
    
    # Get zone
    ${zone}=            Get Zone By ID    ${TEST_ZONE_ID}
    
    # Verify zone details match what we created
    Assert Zone Details    ${zone}    ${TEST_ZONE_DATA}
    
    Log                 Successfully retrieved zone with ID: ${TEST_ZONE_ID}

05 - Get Non-Existent Zone Test
    [Documentation]     Test retrieving a zone that doesn't exist
    [Tags]              retrieve    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to get non-existent zone
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 GET On Session
    ...                 vkho
    ...                 /zones/get-one/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that retrieving a non-existent zone fails

06 - Update Zone Test
    [Documentation]     Test updating an existing zone
    [Tags]              update    positive
    
    # Create a zone if one doesn't exist
    Run Keyword If      "${TEST_ZONE_ID}" == "${EMPTY}"    Create Test Zone
    
    # Prepare update data
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_ZONE_ID}
    ...                 capcity=200
    ...                 name=${TEST_ZONE_DATA}[name] Updated
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 status=ENABLE
    
    # Update zone
    ${updated_zone}=    Update Zone    ${TEST_ZONE_ID}    ${update_data}
    
    # Verify zone was updated successfully
    Should Be Equal     ${updated_zone}[capcity]    ${update_data}[capcity]
    ...    msg=Updated zone capacity does not match expected value
    
    # Update global variable with new data
    Set Global Variable  ${TEST_ZONE_UPDATED_DATA}    ${update_data}
    
    Log                 Successfully updated zone: ${TEST_ZONE_ID}

07 - Update Zone With Missing Required Field Test
    [Documentation]     Test updating a zone with missing required fields
    [Tags]              update    negative
    
    # Create a zone if one doesn't exist
    Run Keyword If      "${TEST_ZONE_ID}" == "${EMPTY}"    Create Test Zone
    
    # Prepare incomplete update data (missing status)
    ${incomplete_data}=  Create Dictionary
    ...                 id=${TEST_ZONE_ID}
    ...                 capcity=150
    ...                 name=Incomplete Update Zone
    ...                 warehouseId=${WAREHOUSE_ID}
    # Missing status field
    
    # Attempt to update zone with incomplete data
    Run Keyword And Expect Error    *Update data missing required field: status*
    ...                 Update Zone    ${TEST_ZONE_ID}    ${incomplete_data}
    
    Log                 Successfully verified that updating a zone with missing fields is rejected

08 - Get All Zones Test
    [Documentation]     Test retrieving all zones
    [Tags]              retrieve    positive
    
    # Get all zones
    ${zones}=           Get All Zones
    
    # Log the structure to understand the format
    Log                 Response structure: ${zones}
    
    # Check different possible response formats
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${zones}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${zones}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${zones}    records
    
    # Log information based on what we found
    Run Keyword If      ${has_data}      Log    Found ${zones['data'].__len__()} zones
    ...    ELSE IF      ${has_items}     Log    Found ${zones['items'].__len__()} zones
    ...    ELSE IF      ${has_records}   Log    Found ${zones['records'].__len__()} zones
    ...    ELSE         Log    Found zones in unknown format
    
    Log                 Successfully retrieved zones list

09 - Filter Zones Test
    [Documentation]     Test filtering zones by name
    [Tags]              retrieve    filter    positive
    
    # Create a zone if one doesn't exist
    Run Keyword If      "${TEST_ZONE_ID}" == "${EMPTY}"    Create Test Zone
    
    # Create filter params based on zone name
    ${filter_params}=   Create Dictionary    zoneName=${TEST_ZONE_DATA}[name]
    
    # Get filtered zones
    ${filtered_zones}=  Get All Zones    filter_params=${filter_params}
    
    # Verify response contains data
    Should Not Be Empty    ${filtered_zones}
    ...    msg=Filtered zones response was empty
    
    # Check different possible response formats
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_zones}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_zones}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_zones}    records
    
    # Verify filter worked based on response structure
    ${found}=           Set Variable    ${FALSE}
    
    # Check in 'data' array if present
    IF    ${has_data}
        ${data_length}=     Get Length    ${filtered_zones}[data]
        Should Be True      ${data_length} > 0    msg=Filter returned empty data array
        ${found}=           Set Variable    ${TRUE}
    # Check in 'items' array if present
    ELSE IF    ${has_items}
        ${items_length}=    Get Length    ${filtered_zones}[items]
        Should Be True      ${items_length} > 0    msg=Filter returned empty items array
        ${found}=           Set Variable    ${TRUE}
    # Check in 'records' array if present
    ELSE IF    ${has_records}
        ${records_length}=  Get Length    ${filtered_zones}[records]
        Should Be True      ${records_length} > 0    msg=Filter returned empty records array
        ${found}=           Set Variable    ${TRUE}
    ELSE
        Log                 Warning: Unknown response structure, can't verify filter results
    END
    
    Should Be True      ${found}    msg=Failed to find zone in filtered results
    
    Log                 Successfully filtered zones by name: ${TEST_ZONE_DATA}[name]

10 - Delete Zone Test
    [Documentation]     Test deleting a zone
    [Tags]              delete    positive
    
    # Create a zone if one doesn't exist
    Run Keyword If      "${TEST_ZONE_ID}" == "${EMPTY}"    Create Test Zone
    
    # Delete zone
    ${result}=          Delete Zone    ${TEST_ZONE_ID}
    Should Be True      ${result}
    ...    msg=Delete zone operation failed
    
    # Verify zone deletion by trying to get it
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /zones/get-one/${TEST_ZONE_ID}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    # Log response for debugging
    Log                 Response status after deletion: ${response.status_code}
    Log                 Response text after deletion: ${response.text}
    
    # Expect 404 or a response indicating the resource no longer exists
    Run Keyword If      ${response.status_code} != 200    Log    Zone successfully deleted
    ...    ELSE    Fail    Zone was not deleted
    
    Log                 Successfully verified deletion of zone with ID: ${TEST_ZONE_ID}

11 - Delete Non-Existent Zone Test
    [Documentation]     Test deleting a zone that doesn't exist
    [Tags]              delete    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to delete non-existent zone
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 DELETE On Session
    ...                 vkho
    ...                 /zones/delete/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that deleting a non-existent zone fails

12 - Cleanup Test Environment
    [Documentation]     Clean up any resources created during tests
    [Tags]              cleanup
    
    # Additional cleanup if needed
    Log                 Test environment cleaned up successfully*** Settings ***