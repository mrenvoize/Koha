<template>
    <Toolbar>
        <ToolbarButton
            :to="{
                name: 'CirculationTriggersFormAdd',
                query: {
                    library_id: selectedLibrary,
                    patron_category_id: selectedCategory,
                    item_type_id: selectedItemType,
                },
            }"
            icon="plus"
            :title="$__('Add new trigger')"
        />
    </Toolbar>
    <div v-if="initialized">
        <h1>{{ $__("Circulation triggers") }}</h1>
        <div class="page-section bg-info">
            <p>
                {{
                    $__(
                        "Rules are applied from most specific to less specific, using the first found in this order"
                    )
                }}:
            </p>
            <ul>
                <li>
                    {{
                        $__(
                            "same library, same patron category, same item type"
                        )
                    }}
                </li>
                <li>
                    {{
                        $__(
                            "same library, same patron category, all item types"
                        )
                    }}
                </li>
                <li>
                    {{
                        $__(
                            "same library, all patron categories, same item type"
                        )
                    }}
                </li>
                <li>
                    {{
                        $__(
                            "same library, all patron categories, all item types"
                        )
                    }}
                </li>
                <li>
                    {{
                        $__(
                            "default (all libraries), same patron category, same item type"
                        )
                    }}
                </li>
                <li>
                    {{
                        $__(
                            "default (all libraries), same patron category, all item types"
                        )
                    }}
                </li>
                <li>
                    {{
                        $__(
                            "default (all libraries), all patron categories, same item type"
                        )
                    }}
                </li>
                <li>
                    {{
                        $__(
                            "default (all libraries), all patron categories, all item types"
                        )
                    }}
                </li>
            </ul>
            <p>
                {{
                    $__(
                        "The system is currently set to match based on the %s"
                    ).format(from_branch)
                }}
            </p>
        </div>
        <div class="page-section" v-if="initialized">
            <legend>Filter by context</legend>
            <table>
                <thead>
                    <tr>
                        <th>{{ $__("Library") }}</th>
                        <th>{{ $__("Category") }}</th>
                        <th>{{ $__("Item type") }}</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td>
                            <v-select
                                id="library_select"
                                v-model="selectedLibrary"
                                label="name"
                                :reduce="lib => lib.library_id"
                                :options="libraries"
                                @update:modelValue="getCircRules()"
                            >
                                <template #search="{ attributes, events }">
                                    <input
                                        :required="!selectedLibrary"
                                        class="vs__search"
                                        v-bind="attributes"
                                        v-on="events"
                                    />
                                </template>
                            </v-select>
                        </td>
                        <td>
                            <v-select
                                id="patron_category_select"
                                v-model="selectedCategory"
                                label="name"
                                :reduce="cat => cat.patron_category_id"
                                :options="patronCategories"
                                @update:modelValue="getCircRules()"
                            >
                                <template #search="{ attributes, events }">
                                    <input
                                        :required="!selectedCategory"
                                        class="vs__search"
                                        v-bind="attributes"
                                        v-on="events"
                                    />
                                </template>
                            </v-select>
                        </td>
                        <td>
                            <v-select
                                id="item_type_select"
                                v-model="selectedItemType"
                                label="description"
                                :reduce="itype => itype.item_type_id"
                                :options="itemTypes"
                                @update:modelValue="getCircRules()"
                            >
                                <template #search="{ attributes, events }">
                                    <input
                                        :required="!selectedItemType"
                                        class="vs__search"
                                        v-bind="attributes"
                                        v-on="events"
                                    />
                                </template>
                            </v-select>
                        </td>
                    </tr>
                </tbody>
            </table>
            <div class="toggle-view-all-applicable-wrapper">
                <label for="filter-rules">{{ $__("Display ") }}</label>
                <select id="filter-rules">
                    <option>
                        all rules that apply to this context, including
                        defaults.
                    </option>
                    <option>only rules specific to this context.</option>
                </select>
            </div>
        </div>
    </div>
    <div v-if="initialized">
        <div id="circ_triggers_tabs" class="toptabs numbered">
            <ul class="nav nav-tabs" role="tablist">
                <li
                    v-for="(number, i) in numberOfTabs"
                    class="nav-item"
                    role="presentation"
                    :key="`noticeTab${i}`"
                >
                    <a
                        href="#"
                        class="nav-link"
                        role="tab"
                        v-bind:class="
                            tabSelected === `Notice ${number}` ? 'active' : ''
                        "
                        @click="changeTabContent"
                        :data-content="`Notice ${number}`"
                        >{{ $__("Trigger") + " " + number }}</a
                    >
                </li>
            </ul>
        </div>
        <div class="tab-content">
            <template v-for="(number, i) in numberOfTabs">
                <div
                    class="tab-pane"
                    role="tabpanel"
                    v-bind:class="
                        tabSelected === `Notice ${number}` ? 'show active' : ''
                    "
                    v-if="tabSelected === `Notice ${number}`"
                    :key="`noticeTabContent${i}`"
                >
                    <TriggersTable
                        :circRules="circRules"
                        :triggerNumber="number"
                        :categories="patronCategories"
                        :itemTypes="itemTypes"
                        :libraries="libraries"
                        :letters="letters"
                        :lostValues="this.lostValues"
                    />
                </div>
            </template>
        </div>
    </div>
    <div v-if="showModal" class="modal" role="dialog">
        <div
            class="modal-dialog modal-dialog-centered modal-lg"
            role="document"
        >
            <router-view></router-view>
        </div>
    </div>
</template>

<script>
import Toolbar from "../../Toolbar.vue";
import ToolbarButton from "../../ToolbarButton.vue";
import { APIClient } from "../../../fetch/api-client.js";
import TriggersTable from "./TriggersTable.vue";
import { inject } from "vue";
import { storeToRefs } from "pinia";

export default {
    setup() {
        const circRulesStore = inject("circRulesStore");
        const { splitCircRulesByTriggerNumber } = circRulesStore;
        const { letters } = storeToRefs(circRulesStore);

        return {
            splitCircRulesByTriggerNumber,
            letters,
            from_branch,
        };
    },
    data() {
        return {
            initialized: false,
            libraries: null,
            selectedLibrary: default_view,
            selectedCategory: "*",
            selectedItemType: "*",
            circRules: null,
            numberOfTabs: [1],
            tabSelected: "Notice 1",
            showModal: false,
            lostValues: [],
        };
    },
    beforeRouteEnter(to, from, next) {
        next(vm => {
            vm.getLostValues().then(
                vm.getLibraries().then(() =>
                    vm.getCategories().then(() =>
                        vm.getItemTypes().then(() =>
                            vm.getCircRules({}, true).then(() => {
                                vm.tabSelected = to.query.trigger
                                    ? `Notice ${to.query.trigger}`
                                    : "Notice 1";
                                vm.initialized = true;
                            })
                        )
                    )
                )
            );
        });
    },
    methods: {
        async getLibraries() {
            const libClient = APIClient.library;
            await libClient.libraries.getAll().then(
                libraries => {
                    libraries.unshift({
                        library_id: "*",
                        name: "Default rules for all libraries",
                    });
                    this.libraries = libraries;
                },
                error => {}
            );
        },
        async getCategories() {
            const client = APIClient.patron;
            await client.patronCategories.getAll().then(
                patronCategories => {
                    patronCategories.unshift({
                        patron_category_id: "*",
                        name: "Default rule",
                    });
                    this.patronCategories = patronCategories;
                },
                error => {}
            );
        },
        async getItemTypes() {
            const client = APIClient.item;
            await client.itemTypes.getAll().then(
                types => {
                    types.unshift({
                        item_type_id: "*",
                        description: "Default rule",
                    });
                    this.itemTypes = types;
                },
                error => {}
            );
        },
        async getCircRules() {
            const library_id = this.selectedLibrary ?? "*";
            const patron_category_id = this.selectedCategory ?? "*";
            const item_type_id = this.selectedItemType ?? "*";

            const client = APIClient.circRule;

            // FIXME: update getAll so that it may retrieve all rows matching a WHERE col_name IN [...array of values] conditions
            await client.circRules.getAll({}, { effective: false }).then(
                rules => {
                    const { numberOfTabs, rulesPerTrigger: circRules } =
                        this.splitCircRulesByTriggerNumber(rules);
                    this.numberOfTabs = numberOfTabs;
                    this.circRules = circRules.filter(
                        circRule =>
                            circRule.context.library_id === library_id &&
                            circRule.context.patron_category_id ===
                                patron_category_id &&
                            circRule.context.item_type_id === item_type_id
                    );
                },
                error => {}
            );
        },
        async getLostValues() {
            const client = APIClient.authorised_values;
            await client.values.get("lost").then(lostValues => {
                this.lostValues = lostValues;
            });
        },
        changeTabContent(e) {
            this.tabSelected = e.target.getAttribute("data-content");
        },
    },
    watch: {
        $route: {
            immediate: true,
            handler: function (newVal, oldVal) {
                this.showModal = newVal.meta && newVal.meta.showModal;
            },
        },
    },
    components: { TriggersTable, Toolbar, ToolbarButton },
};
</script>

<style scoped>
.page-section table {
    width: 100%;
    table-layout: fixed;
}
.page-section th,
.page-section td {
    width: 33%;
}
.page-section td {
    padding: 0.5em;
    vertical-align: top;
}
.v-select {
    display: block;
    background-color: white;
    margin: 10px;
    height: auto; /* Restore original height */
}
.vs__search,
.v__selected {
    display: inline-block;
    vertical-align: middle;
}
.active {
    cursor: pointer;
}
.toptabs {
    margin-bottom: 0;
}
.toggle-view-all-applicable-wrapper {
    margin: 10px;
}

.modal {
    position: fixed;
    z-index: 9998;
    display: table;
    transition: opacity 0.3s ease;
    left: 0px;
    top: 0px;
    width: 100%;
    height: 100%;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.33);
}
.modal-dialog {
    overflow: auto;
    height: 90%;
}
</style>
