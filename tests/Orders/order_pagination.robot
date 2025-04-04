*** Settings ***
Documentation     Test Suite for Order Pagination and Filtering in vKho API
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Resource          ../../Variables/variables.robot

*** Keywords ***
Setup API Session
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${USERNAME}    password=${PASSWORD}
    ${response}=        POST On Session    vkho    /auth/login    json=${body}    headers=${headers}    expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${AUTH_TOKEN}    ${token}
    Create Directory    ${RESULTS_DIR}

Create Test Order
    [Arguments]         ${suffix}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${order_code}=      Set Variable     ORDPAGE${timestamp}${suffix}
    ${product_order}=   Create Dictionary    total=5    boothCode=BOOTH${timestamp}    sku=SKU${timestamp}
    ${product_orders}=  Create List      ${product_order}
    ${order_data}=      Create Dictionary
    ...                 nameCustomer=Pagination Test ${timestamp}
    ...                 code=${order_code}
    ...                 boothCode=BOOTH${timestamp}
    ...                 deliveryAdress=Test Address
    ...                 deliveryTime=2025-04-01T12:00:00.000Z
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 productOrders=${product_orders}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session    vkho    /orders/create    json=${order_data}    headers=${headers}    expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}[id]

Get Paginated Orders
    [Arguments]         ${page}    ${limit}    ${filter_params}=${EMPTY}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${params}=          Create Dictionary    warehouseId=${WAREHOUSE_ID}    page=${page}    limit=${limit}
    Run Keyword If      "${filter_params}" != "${EMPTY}"    Set To Dictionary    ${params}    &{filter_params}
    ${response}=        GET On Session    vkho    /orders/get-all    params=${params}    headers=${headers}    expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}

*** Test Cases ***
01 - Setup Environment
    [Tags]              setup
    Setup API Session

02 - Create Multiple Orders for Pagination
    [Documentation]     Create test orders for pagination testing
    [Tags]              setup    positive
    FOR    ${i}    IN RANGE    5
        ${order_id}=    Create Test Order    ${i}
        Append To List    ${TEST_ORDER_IDS}    ${order_id}
    END
    Log                 Created ${TEST_ORDER_IDS.__len__()} test orders

03 - Test Pagination
    [Documentation]     Test paginated retrieval of orders
    [Tags]              pagination    positive
    ${page1}=           Get Paginated Orders    1    2
    ${data_length}=     Get Length    ${page1}[data]
    Should Be Equal As Integers    ${data_length}    2
    Should Contain Key    ${page1}    totalPages
    
    ${page2}=           Get Paginated Orders    2    2
    ${data_length}=     Get Length    ${page2}[data]
    Should Be True      ${data_length} <= 2
    
    Log                 Successfully validated pagination with pageSize=2

04 - Test Filtering by Status
    [Documentation]     Test filtering orders by status
    [Tags]              filter    positive
    ${filter_params}=   Create Dictionary    status=CREATED
    ${filtered}=        Get Paginated Orders    1    10    ${filter_params}
    ${data}=            Set Variable    ${filtered}[data]
    FOR    ${order}    IN    @{data}
        Should Be Equal    ${order}[status]    CREATED
    END
    Log                 Successfully validated filtering by status CREATED