*** Settings ***
Documentation     Advanced Test Suite for Package Operations in vKho API
...               Includes complex scenarios like bulk operations, dependencies, and edge cases
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Library           BuiltIn
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
    [Arguments]         ${custom_code}=Test Package
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${package_code}=    Set Variable     ${custom_code}${timestamp}
    
    # Return dictionary of generated data
    ${package_data}=    Create Dictionary
    ...                 packageCode=${package_code}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 status=CREATED
    RETURN            ${package_data}

Create Package
    [Documentation]     Create a new package and return its ID
    [Arguments]         ${package_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${package_data}    packageCode
    ...    msg=Missing required parameter: packageCode
    Dictionary Should Contain Key    ${package_data}    warehouseId
    ...    msg=Missing required parameter: warehouseId
    Dictionary Should Contain Key    ${package_data}    status
    ...    msg=Missing required parameter: status
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send create package request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /packages/create
    ...                 json=${package_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
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
    Dictionary Should Contain Key    ${update_data}    packageCode
    ...    msg=Update data missing required field: packageCode
    Dictionary Should Contain Key    ${update_data}    warehouseId
    ...    msg=Update data missing required field: warehouseId
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
    [Arguments]         ${filter_params}=${EMPTY}
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Create params dictionary if filters are provided
    ${params}=          Create Dictionary
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

Create Order With Package
    [Documentation]     Create an order linked to a package
    [Arguments]         ${package_id}
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${product_order}=   Create Dictionary
    ...                 total=5
    ...                 boothCode=BTH${timestamp}
    ...                 sku=SKU${timestamp}
    ${product_orders}=  Create List      ${product_order}
    
    ${order_data}=      Create Dictionary
    ...                 nameCustomer=Order for Package ${package_id}
    ...                 code=ORD${timestamp}
    ...                 boothCode=BTH${timestamp}
    ...                 deliveryAdress=789 Order Street
    ...                 deliveryTime=2025-04-05T10:00:00.000Z
    ...                 driverName=John Doe
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 productOrders=${product_orders}
    ...                 packageId=${package_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /orders/create
    ...                 json=${order_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${order_id}=        Convert To String    ${json}[id]
    RETURN            ${order_id}

Bulk Create Packages
    [Documentation]     Create multiple packages in bulk
    [Arguments]         ${count}=3
    
    ${package_ids}=     Create List
    FOR    ${i}    IN RANGE    ${count}
        ${package_data}=    Generate Unique Package Data    custom_code=PKG${i}
        ${package_id}    ${response}=    Create Package    ${package_data}
        Append To List      ${package_ids}    ${package_id}
    END
    RETURN            ${package_ids}

Assert Package Details
    [Documentation]     Verify package details match expected values
    [Arguments]         ${package}    ${expected_data}
    
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${package}    Should Be Equal    ${package}[${key}]    ${expected_data}[${key}]
        ...    msg=Package ${key} value '${package}[${key}]' does not match expected '${expected_data}[${key}]'
    END

Create Test Package
    [Documentation]     Creates a test package if one doesn't exist
    ${package_data}=    Generate Unique Package Data
    ${package_id}    ${response}=    Create Package    ${package_data}
    Set Global Variable  ${TEST_PACKAGE_ID}      ${package_id}
    Set Global Variable  ${TEST_PACKAGE_CODE}    ${response}[packageCode]
    Set Global Variable  ${TEST_PACKAGE_DATA}    ${package_data}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for complex package tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Bulk Package Creation Test
    [Documentation]     Test creating multiple packages in bulk
    [Tags]              create    bulk    positive
    
    ${bulk_ids}=        Bulk Create Packages    count=3
    Should Not Be Empty    ${bulk_ids}
    ...    msg=Failed to create bulk packages: No IDs returned
    Should Be Equal As Integers    ${bulk_ids.__len__()}    3
    ...    msg=Expected 3 packages, but created ${bulk_ids.__len__()}
    
    Set Global Variable  ${BULK_PACKAGE_IDS}    ${bulk_ids}
    Log                 Successfully created ${bulk_ids.__len__()} packages: ${bulk_ids}

03 - Create Package With Duplicate Code Test
    [Documentation]     Test creating a package with a duplicate packageCode
    [Tags]              create    negative
    
    # Create first package
    ${package_data}=    Generate Unique Package Data    custom_code=DuplicatePKG
    ${package_id}    ${response}=    Create Package    ${package_data}
    
    # Attempt to create second package with same code
    ${duplicate_data}=  Create Dictionary    &{package_data}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /packages/create
    ...                 json=${duplicate_data}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    Should Not Equal As Integers    ${response.status_code}    201
    ...    msg=API allowed creation of package with duplicate packageCode
    Log                 Successfully verified duplicate packageCode rejection: ${response.text}

04 - Package With Order Dependency Test
    [Documentation]     Test creating and retrieving a package with a dependent order
    [Tags]              create    retrieve    dependency    positive
    
    # Create package
    ${package_data}=    Generate Unique Package Data    custom_code=DependencyPKG
    ${package_id}    ${response}=    Create Package    ${package_data}
    
    # Create order linked to package
    ${order_id}=        Create Order With Package    ${package_id}
    Should Not Be Empty    ${order_id}
    ...    msg=Failed to create order linked to package
    
    # Retrieve package and verify
    ${package}=         Get Package By ID    ${package_id}
    Assert Package Details    ${package}    ${package_data}
    Log                 Successfully created and retrieved package ${package_id} with order ${order_id}

05 - Update Package Status Transition Test
    [Documentation]     Test updating package status through multiple states
    [Tags]              update    state-transition    positive
    
    # Create package
    ${package_data}=    Generate Unique Package Data    custom_code=StateTransitionPKG
    ${package_id}    ${response}=    Create Package    ${package_data}
    
    # Update to PICKING
    ${update_data_1}=   Create Dictionary
    ...                 id=${package_id}
    ...                 packageCode=${package_data}[packageCode]
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 status=PICKING
    ${updated_1}=       Update Package    ${package_id}    ${update_data_1}
    Should Be Equal     ${updated_1}[status]    PICKING
    ...    msg=Failed to transition package to PICKING
    
    # Update to DELIVERING
    ${update_data_2}=   Create Dictionary
    ...                 id=${package_id}
    ...                 packageCode=${package_data}[packageCode]
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 status=DELIVERING
    ${updated_2}=       Update Package    ${package_id}    ${update_data_2}
    Should Be Equal     ${updated_2}[status]    DELIVERING
    ...    msg=Failed to transition package to DELIVERING
    
    # Verify final state
    ${final_package}=   Get Package By ID    ${package_id}
    Should Be Equal     ${final_package}[status]    DELIVERING
    ...    msg=Final package status does not match expected value
    
    Log                 Successfully transitioned package ${package_id} through multiple states

06 - Filter Packages By Status And Code Test
    [Documentation]     Test filtering packages with multiple parameters
    [Tags]              retrieve    filter    positive
    
    # Create test package if not exists
    Run Keyword If      "${TEST_PACKAGE_ID}" == "${EMPTY}"    Create Test Package
    
    # Filter by packageCode and status
    ${filter_params}=   Create Dictionary
    ...                 packageCode=${TEST_PACKAGE_CODE}
    ...                 status=CREATED
    
    ${filtered_packages}=    Get All Packages    filter_params=${filter_params}
    Should Not Be Empty    ${filtered_packages}
    ...    msg=Filtered packages response was empty
    
    # Check response structure and verify result
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_packages}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_packages}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_packages}    records
    
    ${found}=           Set Variable    ${FALSE}
    IF    ${has_data}
        ${data_length}=     Get Length    ${filtered_packages}[data]
        Should Be True      ${data_length} > 0    msg=Filter returned empty data array
        ${found}=           Set Variable    ${TRUE}
    ELSE IF    ${has_items}
        ${items_length}=    Get Length    ${filtered_packages}[items]
        Should Be True      ${items_length} > 0    msg=Filter returned empty items array
        ${found}=           Set Variable    ${TRUE}
    ELSE IF    ${has_records}
        ${records_length}=  Get Length    ${filtered_packages}[records]
        Should Be True      ${records_length} > 0    msg=Filter returned empty records array
        ${found}=           Set Variable    ${TRUE}
    END
    
    Should Be True      ${found}    msg=Failed to find package with multiple filters
    Log                 Successfully filtered packages with code: ${TEST_PACKAGE_CODE} and status: CREATED

07 - Delete Package With Order Dependency Test
    [Documentation]     Test deleting a package with a dependent order
    [Tags]              delete    dependency    negative
    
    # Create package
    ${package_data}=    Generate Unique Package Data    custom_code=DeleteDependencyPKG
    ${package_id}    ${response}=    Create Package    ${package_data}
    
    # Create order linked to package
    ${order_id}=        Create Order With Package    ${package_id}
    
    # Attempt to delete package with dependency
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /packages/delete/${package_id}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    # Expect failure due to dependency (assuming API enforces this)
    Should Not Equal As Integers    ${response.status_code}    200
    ...    msg=API allowed deletion of package with dependent order
    Log                 Successfully verified rejection of package deletion with order ${order_id}

08 - Edge Case - Package With Maximum Length Code Test
    [Documentation]     Test creating a package with maximum length packageCode
    [Tags]              create    edge    positive
    
    ${long_code}=       Set Variable    PKG${"X" * 100}    # Assuming 100 char limit
    
    ${package_data}=    Create Dictionary
    ...                 packageCode=${long_code}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 status=CREATED
    
    ${package_id}    ${response}=    Create Package    ${package_data}
    Should Not Be Empty    ${package_id}
    ...    msg=Failed to create package with max length packageCode
    
    ${package}=         Get Package By ID    ${package_id}
    Should Be Equal     ${package}[packageCode]    ${long_code}
    ...    msg=Created package code does not match max length input
    Log                 Successfully created package with maximum length packageCode: ${package_id}

09 - Cleanup Test Environment
    [Documentation]     Clean up resources created during complex tests
    [Tags]              cleanup
    
    # Clean up bulk packages if created
    Run Keyword If      "${BULK_PACKAGE_IDS}" != "${EMPTY}"
    ...                 Run Keywords
    ...                 FOR    ${id}    IN    @{BULK_PACKAGE_IDS}
    ...                 Delete Package    ${id}
    ...                 END
    ...                 AND    Set Global Variable    ${BULK_PACKAGE_IDS}    ${EMPTY}
    
    # Clean up test package if created
    Run Keyword If      "${TEST_PACKAGE_ID}" != "${EMPTY}"
    ...                 Delete Package    ${TEST_PACKAGE_ID}
    ...                 AND    Set Global Variable    ${TEST_PACKAGE_ID}    ${EMPTY}
    
    Log                 Test environment cleaned up successfully  