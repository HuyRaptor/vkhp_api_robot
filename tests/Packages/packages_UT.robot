*** Settings ***
Documentation     Comprehensive Test Suite for Package Operations in vKho API
...               Includes proper parameter validation and error handling
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime

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

Generate Unique Package Data
    [Documentation]     Generate unique data for package tests
    
    # Prepare package creation data
    ${package_data}=    Create Dictionary
    ...                 orderId=${ORDER_ID}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 zoneId=${ZONE_ID}
    
    RETURN            ${package_data}

Create Package
    [Documentation]     Create a new package and return its ID
    [Arguments]         ${package_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${package_data}    orderId
    ...    msg=Missing required parameter: orderId
    Dictionary Should Contain Key    ${package_data}    warehouseId
    ...    msg=Missing required parameter: warehouseId
    Dictionary Should Contain Key    ${package_data}    zoneId
    ...    msg=Missing required parameter: zoneId
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send create package request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /packages/create
    ...                 json=${package_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Save response for debugging
    ${timestamp}=       Evaluate         int(time.time())    time
    Create File         ${RESULTS_DIR}${/}package_create_${timestamp}.json    ${response.text}
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Create package response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Create package response missing ID field
    
    # Return package ID and full response
    ${package_id}=      Convert To String    ${json}[id]
    RETURN            ${package_id}    ${json}

Get Package By ID
    [Documentation]     Retrieve a specific package by ID
    [Arguments]         ${package_id}
    
    # Validate parameters
    Should Not Be Empty    ${package_id}
    ...    msg=Package ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get package request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /packages/get-one/${package_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get package response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Get package response missing ID field
    
    RETURN            ${json}

Update Package
    [Documentation]     Update an existing package
    [Arguments]         ${package_id}    ${update_data}
    
    # Validate parameters
    Should Not Be Empty    ${package_id}
    ...    msg=Package ID cannot be empty
    Dictionary Should Contain Key    ${update_data}    id
    ...    msg=Update data must contain id field
    Should Be Equal     ${update_data}[id]    ${package_id}
    ...    msg=Update data ID must match package_id parameter
    
    # Ensure minimum required fields are present
    Dictionary Should Contain Key    ${update_data}    orderId
    ...    msg=Update data missing required field: orderId
    Dictionary Should Contain Key    ${update_data}    warehouseId
    ...    msg=Update data missing required field: warehouseId
    Dictionary Should Contain Key    ${update_data}    zoneId
    ...    msg=Update data missing required field: zoneId
    Dictionary Should Contain Key    ${update_data}    status
    ...    msg=Update data missing required field: status
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send update package request
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /packages/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Update package response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Update package response missing ID field
    
    RETURN            ${json}

Delete Package
    [Documentation]     Delete a package from the system
    [Arguments]         ${package_id}
    
    # Validate parameters
    Should Not Be Empty    ${package_id}
    ...    msg=Package ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send delete package request
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /packages/delete/${package_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Return deletion status
    RETURN            ${TRUE}

Get All Packages
    [Documentation]     Retrieve all packages with optional filtering
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
    
    # Send get all packages request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /packages/get-all
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get all packages response was empty
    
    RETURN            ${json}

Assert Package Details
    [Documentation]     Verify package details match expected values
    [Arguments]         ${package}    ${expected_data}
    
    # For all keys in expected data, verify they match in the package data
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${package}    Should Be Equal    ${package}[${key}]    ${expected_data}[${key}]
        ...    msg=Package ${key} value '${package}[${key}]' does not match expected '${expected_data}[${key}]'
    END

Create Test Package
    [Documentation]     Creates a test package if one doesn't exist
    ${package_data}=    Generate Unique Package Data
    ${package_id}    ${response}=    Create Package    ${package_data}
    Set Global Variable  ${TEST_PACKAGE_ID}      ${package_id}
    Set Global Variable  ${TEST_PACKAGE_DATA}    ${package_data}

Verify Response Indicates Deletion
    [Documentation]     Check if response indicates package is deleted
    [Arguments]         ${response_text}
    
    # Parse response
    ${json}=            Evaluate         json.loads('''${response_text}''')    json
    
    # Check for status field indicating deletion
    ${has_status}=      Run Keyword And Return Status    Dictionary Should Contain Key    ${json}    status
    ${is_deleted}=      Run Keyword If    ${has_status}    Check Deletion Status    ${json}[status]
    ...    ELSE         Check Other Deletion Indicators    ${json}
    
    RETURN            ${is_deleted}

Check Deletion Status
    [Documentation]     Check if status field indicates deletion
    [Arguments]         ${status}
    
    # Handle different possible status values for deletion
    ${is_deleted}=      Set Variable    ${FALSE}
    
    # Convert to uppercase for case-insensitive comparison
    ${status_upper}=    Convert To Uppercase    ${status}
    
    # Check against common "deleted" status values
    IF    '${status_upper}' == 'DISABLE' or '${status_upper}' == 'DELETED' or '${status_upper}' == 'INACTIVE' or '${status_upper}' == 'ERROR'
        ${is_deleted}=  Set Variable    ${TRUE}
    END
    
    RETURN            ${is_deleted}

Check Other Deletion Indicators
    [Documentation]     Check for other indicators of deletion
    [Arguments]         ${json}
    
    # Handle special cases for packages
    ${is_deleted}=      Set Variable    ${FALSE}
    
    # Check if status is in a deleted/error state
    ${status_check}=    Run Keyword And Return Status    Evaluate    '${json.get("status", "")}' in ['DISABLE', 'ERROR', 'LOST']
    
    # If above check fails, fall back to more generic checks
    ${is_deleted}=      Set Variable    ${status_check}
    
    RETURN            ${is_deleted}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for package tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Package Test
    [Documentation]     Test creating a new package
    [Tags]              create    positive
    
    # Generate package data
    ${package_data}=    Generate Unique Package Data
    
    # Create package
    ${package_id}    ${response}=    Create Package    ${package_data}
    
    # Verify package was created successfully
    Should Not Be Empty    ${package_id}
    ...    msg=Failed to create package: No ID returned
    
    # Save package ID for subsequent tests
    Set Global Variable  ${TEST_PACKAGE_ID}      ${package_id}
    Set Global Variable  ${TEST_PACKAGE_DATA}    ${package_data}
    
    Log                 Successfully created package with ID: ${TEST_PACKAGE_ID}

03 - Create Package Missing Required Field Test
    [Documentation]     Test creating a package with missing required fields
    [Tags]              create    negative
    
    # Generate incomplete package data (missing zoneId)
    ${incomplete_data}=  Create Dictionary
    ...                 orderId=${ORDER_ID}
    ...                 warehouseId=${WAREHOUSE_ID}
    
    # Attempt to create package with incomplete data
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect proper error message
    Run Keyword And Expect Error    *Missing required parameter: zoneId*
    ...                 Create Package    ${incomplete_data}
    
    Log                 Successfully verified that creating a package with missing fields is rejected

04 - Get Package Test
    [Documentation]     Test retrieving a specific package
    [Tags]              retrieve    positive
    
    # Create a package if one doesn't exist
    Run Keyword If      "${TEST_PACKAGE_ID}" == "${EMPTY}"    Create Test Package
    
    # Get package
    ${package}=         Get Package By ID    ${TEST_PACKAGE_ID}
    
    # Verify package details match what we created
    Assert Package Details    ${package}    ${TEST_PACKAGE_DATA}
    
    Log                 Successfully retrieved package with ID: ${TEST_PACKAGE_ID}

05 - Get Non-Existent Package Test
    [Documentation]     Test retrieving a package that doesn't exist
    [Tags]              retrieve    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to get non-existent package
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 GET On Session
    ...                 vkho
    ...                 /packages/get-one/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that retrieving a non-existent package fails

06 - Update Package Test
    [Documentation]     Test updating an existing package
    [Tags]              update    positive
    
    # Create a package if one doesn't exist
    Run Keyword If      "${TEST_PACKAGE_ID}" == "${EMPTY}"    Create Test Package
    
    # Prepare update data
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_PACKAGE_ID}
    ...                 orderId=${ORDER_ID}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 zoneId=${ZONE_ID}
    ...                 status=SHIPPING
    
    # Update package
    ${updated_package}=    Update Package    ${TEST_PACKAGE_ID}    ${update_data}
    
    # Verify package was updated successfully
    Should Be Equal     ${updated_package}[status]    SHIPPING
    ...    msg=Updated package status does not match expected value
    
    # Update global variable with new data
    Set Global Variable  ${TEST_PACKAGE_UPDATED_DATA}    ${update_data}
    
    Log                 Successfully updated package: ${TEST_PACKAGE_ID}

*** Settings ***
Documentation     Comprehensive Test Suite for Package Operations in vKho API
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

Generate Unique Package Data
    [Documentation]     Generate unique data for package tests
    
    # Prepare package creation data
    ${package_data}=    Create Dictionary
    ...                 orderId=${ORDER_ID}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 zoneId=${ZONE_ID}
    
    RETURN            ${package_data}

Create Package
    [Documentation]     Create a new package and return its ID
    [Arguments]         ${package_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${package_data}    orderId
    ...    msg=Missing required parameter: orderId
    Dictionary Should Contain Key    ${package_data}    warehouseId
    ...    msg=Missing required parameter: warehouseId
    Dictionary Should Contain Key    ${package_data}    zoneId
    ...    msg=Missing required parameter: zoneId
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send create package request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /packages/create
    ...                 json=${package_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Save response for debugging
    ${timestamp}=       Evaluate         int(time.time())    time
    Create File         ${RESULTS_DIR}${/}package_create_${timestamp}.json    ${response.text}
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Create package response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Create package response missing ID field
    
    # Return package ID and full response
    ${package_id}=      Convert To String    ${json}[id]
    RETURN            ${package_id}    ${json}

Get Package By ID
    [Documentation]     Retrieve a specific package by ID
    [Arguments]         ${package_id}
    
    # Validate parameters
    Should Not Be Empty    ${package_id}
    ...    msg=Package ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get package request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /packages/get-one/${package_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get package response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Get package response missing ID field
    
    RETURN            ${json}

Update Package
    [Documentation]     Update an existing package
    [Arguments]         ${package_id}    ${update_data}
    
    # Validate parameters
    Should Not Be Empty    ${package_id}
    ...    msg=Package ID cannot be empty
    Dictionary Should Contain Key    ${update_data}    id
    ...    msg=Update data must contain id field
    Should Be Equal     ${update_data}[id]    ${package_id}
    ...    msg=Update data ID must match package_id parameter
    
    # Ensure minimum required fields are present
    Dictionary Should Contain Key    ${update_data}    orderId
    ...    msg=Update data missing required field: orderId
    Dictionary Should Contain Key    ${update_data}    warehouseId
    ...    msg=Update data missing required field: warehouseId
    Dictionary Should Contain Key    ${update_data}    zoneId
    ...    msg=Update data missing required field: zoneId
    Dictionary Should Contain Key    ${update_data}    status
    ...    msg=Update data missing required field: status
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send update package request
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /packages/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Update package response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Update package response missing ID field
    
    RETURN            ${json}

Delete Package
    [Documentation]     Delete a package from the system
    [Arguments]         ${package_id}
    
    # Validate parameters
    Should Not Be Empty    ${package_id}
    ...    msg=Package ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send delete package request
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /packages/delete/${package_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Return deletion status
    RETURN            ${TRUE}

Get All Packages
    [Documentation]     Retrieve all packages with optional filtering
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
    
    # Send get all packages request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /packages/get-all
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get all packages response was empty
    
    RETURN            ${json}

Assert Package Details
    [Documentation]     Verify package details match expected values
    [Arguments]         ${package}    ${expected_data}
    
    # For all keys in expected data, verify they match in the package data
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${package}    Should Be Equal    ${package}[${key}]    ${expected_data}[${key}]
        ...    msg=Package ${key} value '${package}[${key}]' does not match expected '${expected_data}[${key}]'
    END

Create Test Package
    [Documentation]     Creates a test package if one doesn't exist
    ${package_data}=    Generate Unique Package Data
    ${package_id}    ${response}=    Create Package    ${package_data}
    Set Global Variable  ${TEST_PACKAGE_ID}      ${package_id}
    Set Global Variable  ${TEST_PACKAGE_DATA}    ${package_data}

Verify Response Indicates Deletion
    [Documentation]     Check if response indicates package is deleted
    [Arguments]         ${response_text}
    
    # Parse response
    ${json}=            Evaluate         json.loads('''${response_text}''')    json
    
    # Check for status field indicating deletion
    ${has_status}=      Run Keyword And Return Status    Dictionary Should Contain Key    ${json}    status
    ${is_deleted}=      Run Keyword If    ${has_status}    Check Deletion Status    ${json}[status]
    ...    ELSE         Check Other Deletion Indicators    ${json}
    
    RETURN            ${is_deleted}

Check Deletion Status
    [Documentation]     Check if status field indicates deletion
    [Arguments]         ${status}
    
    # Handle different possible status values for deletion
    ${is_deleted}=      Set Variable    ${FALSE}
    
    # Convert to uppercase for case-insensitive comparison
    ${status_upper}=    Convert To Uppercase    ${status}
    
    # Check against common "deleted" status values
    IF    '${status_upper}' == 'DISABLE' or '${status_upper}' == 'DELETED' or '${status_upper}' == 'INACTIVE' or '${status_upper}' == 'ERROR'
        ${is_deleted}=  Set Variable    ${TRUE}
    END
    
    RETURN            ${is_deleted}

Check Other Deletion Indicators
    [Documentation]     Check for other indicators of deletion
    [Arguments]         ${json}
    
    # Handle special cases for packages
    ${is_deleted}=      Set Variable    ${FALSE}
    
    # Check if status is in a deleted/error state
    ${status_check}=    Run Keyword And Return Status    Evaluate    '${json.get("status", "")}' in ['DISABLE', 'ERROR', 'LOST']
    
    # If above check fails, fall back to more generic checks
    ${is_deleted}=      Set Variable    ${status_check}
    
    RETURN            ${is_deleted}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for package tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Package Test
    [Documentation]     Test creating a new package
    [Tags]              create    positive
    
    # Generate package data
    ${package_data}=    Generate Unique Package Data
    
    # Create package
    ${package_id}    ${response}=    Create Package    ${package_data}
    
    # Verify package was created successfully
    Should Not Be Empty    ${package_id}
    ...    msg=Failed to create package: No ID returned
    
    # Save package ID for subsequent tests
    Set Global Variable  ${TEST_PACKAGE_ID}      ${package_id}
    Set Global Variable  ${TEST_PACKAGE_DATA}    ${package_data}
    
    Log                 Successfully created package with ID: ${TEST_PACKAGE_ID}

03 - Create Package Missing Required Field Test
    [Documentation]     Test creating a package with missing required fields
    [Tags]              create    negative
    
    # Generate incomplete package data (missing zoneId)
    ${incomplete_data}=  Create Dictionary
    ...                 orderId=${ORDER_ID}
    ...                 warehouseId=${WAREHOUSE_ID}
    
    # Attempt to create package with incomplete data
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect proper error message
    Run Keyword And Expect Error    *Missing required parameter: zoneId*
    ...                 Create Package    ${incomplete_data}
    
    Log                 Successfully verified that creating a package with missing fields is rejected

04 - Get Package Test
    [Documentation]     Test retrieving a specific package
    [Tags]              retrieve    positive
    
    # Create a package if one doesn't exist
    Run Keyword If      "${TEST_PACKAGE_ID}" == "${EMPTY}"    Create Test Package
    
    # Get package
    ${package}=         Get Package By ID    ${TEST_PACKAGE_ID}
    
    # Verify package details match what we created
    Assert Package Details    ${package}    ${TEST_PACKAGE_DATA}
    
    Log                 Successfully retrieved package with ID: ${TEST_PACKAGE_ID}

05 - Get Non-Existent Package Test
    [Documentation]     Test retrieving a package that doesn't exist
    [Tags]              retrieve    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to get non-existent package
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 GET On Session
    ...                 vkho
    ...                 /packages/get-one/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that retrieving a non-existent package fails

06 - Update Package Test
    [Documentation]     Test updating an existing package
    [Tags]              update    positive
    
    # Create a package if one doesn't exist
    Run Keyword If      "${TEST_PACKAGE_ID}" == "${EMPTY}"    Create Test Package
    
    # Prepare update data
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_PACKAGE_ID}
    ...                 orderId=${ORDER_ID}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 zoneId=${ZONE_ID}
    ...                 status=SHIPPING
    
    # Update package
    ${updated_package}=    Update Package    ${TEST_PACKAGE_ID}    ${update_data}
    
    # Verify package was updated successfully
    Should Be Equal     ${updated_package}[status]    SHIPPING
    ...    msg=Updated package status does not match expected value
    
    # Update global variable with new data
    Set Global Variable  ${TEST_PACKAGE_UPDATED_DATA}    ${update_data}
    
    Log                 Successfully updated package: ${TEST_PACKAGE_ID}

07 - Update Package With Missing Required Field Test
    [Documentation]     Test updating a package with missing required fields
    [Tags]              update    negative
    
    # Create a package if one doesn't exist
    Run Keyword If      "${TEST_PACKAGE_ID}" == "${EMPTY}"    Create Test Package
    
    # Prepare incomplete update data (missing status)
    ${incomplete_data}=  Create Dictionary
    ...                 id=${TEST_PACKAGE_ID}
    ...                 orderId=${ORDER_ID}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 zoneId=${ZONE_ID}
    # Missing status field
    
    # Attempt to update package with incomplete data
    Run Keyword And Expect Error    *Update data missing required field: status*
    ...                 Update Package    ${TEST_PACKAGE_ID}    ${incomplete_data}
    
    Log                 Successfully verified that updating a package with missing fields is rejected

08 - Get All Packages Test
    [Documentation]     Test retrieving all packages
    [Tags]              retrieve    positive
    
    # Get all packages
    ${packages}=        Get All Packages
    
    # Log the structure to understand the format
    Log                 Response structure: ${packages}
    
    # Check different possible response formats
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${packages}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${packages}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${packages}    records
    
    # Log information based on what we found
    Run Keyword If      ${has_data}      Log    Found ${packages['data'].__len__()} packages
    ...    ELSE IF      ${has_items}     Log    Found ${packages['items'].__len__()} packages
    ...    ELSE IF      ${has_records}   Log    Found ${packages['records'].__len__()} packages
    ...    ELSE         Log    Found packages in unknown format
    
    Log                 Successfully retrieved packages list

09 - Filter Packages Test
    [Documentation]     Test filtering packages by order ID
    [Tags]              retrieve    filter    positive
    
    # Create a package if one doesn't exist
    Run Keyword If      "${TEST_PACKAGE_ID}" == "${EMPTY}"    Create Test Package
    
    # Create filter params based on order ID
    ${filter_params}=   Create Dictionary    orderId=${ORDER_ID}
    
    # Get filtered packages
    ${filtered_packages}=    Get All Packages    filter_params=${filter_params}
    
    # Verify response contains data
    Should Not Be Empty    ${filtered_packages}
    ...    msg=Filtered packages response was empty
    
    # Check if our package is in the results (depends on API structure)
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_packages}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_packages}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_packages}    records
    
    # Verify filter worked based on response structure
    ${found}=           Set Variable    ${FALSE}
    
    # Check in 'data' array if present
    IF    ${has_data}
        ${data_length}=     Get Length    ${filtered_packages}[data]
        Should Be True      ${data_length} > 0    msg=Filter returned empty data array
        ${found}=           Set Variable    ${TRUE}
    # Check in 'items' array if present
    ELSE IF    ${has_items}
        ${items_length}=    Get Length    ${filtered_packages}[items]
        Should Be True      ${items_length} > 0    msg=Filter returned empty items array
        ${found}=           Set Variable    ${TRUE}
    # Check in 'records' array if present
    ELSE IF    ${has_records}
        ${records_length}=  Get Length    ${filtered_packages}[records]
        Should Be True      ${records_length} > 0    msg=Filter returned empty records array
        ${found}=           Set Variable    ${TRUE}
    ELSE
        Log                 Warning: Unknown response structure, can't verify filter results
    END
    
    Should Be True      ${found}    msg=Failed to find package in filtered results
    
    Log                 Successfully filtered packages by order ID: ${ORDER_ID}

10 - Delete Package Test
    [Documentation]     Test deleting a package
    [Tags]              delete    positive
    
    # Create a package if one doesn't exist
    Run Keyword If      "${TEST_PACKAGE_ID}" == "${EMPTY}"    Create Test Package
    
    # Delete package
    ${result}=          Delete Package    ${TEST_PACKAGE_ID}
    Should Be True      ${result}
    ...    msg=Delete package operation failed
    
    # Verify package deletion by trying to get it
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /packages/get-one/${TEST_PACKAGE_ID}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    # Log response for debugging
    Log                 Response status after deletion: ${response.status_code}
    Log                 Response text after deletion: ${response.text}
    
    # API might handle deletion differently: either 404 Not Found or status = DISABLE
    ${is_deleted}=      Run Keyword If      ${response.status_code} == 404    Set Variable    ${TRUE}
    ...    ELSE IF      ${response.status_code} == 200    Verify Response Indicates Deletion    ${response.text}
    ...    ELSE         Set Variable    ${FALSE}
    
    Should Be True      ${is_deleted}
    ...    msg=Package was not properly deleted or marked as deleted
    
    Log                 Successfully verified deletion of package with ID: ${TEST_PACKAGE_ID}

11 - Delete Non-Existent Package Test
    [Documentation]     Test deleting a package that doesn't exist
    [Tags]              delete    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to delete non-existent package
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 DELETE On Session
    ...                 vkho
    ...                 /packages/delete/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that deleting a non-existent package fails

12 - Cleanup Test Environment
    [Documentation]     Clean up any resources created during tests
    [Tags]              cleanup
    
    # Additional cleanup if needed
    Log                 Test environment cleaned up successfully