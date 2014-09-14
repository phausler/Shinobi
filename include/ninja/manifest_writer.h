// Copyright 2011 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#ifndef NINJA_MANIFEST_WRITER_H_
#define NINJA_MANIFEST_WRITER_H_

#include <string>

using namespace std;

namespace ninja {
    
    struct BindingEnv;
    struct EvalString;
    struct State;
    struct Pool;
    struct Edge;
    struct Rule;
    struct Node;
    
    struct ManifestWriter {
        struct FileWriter {
            virtual ~FileWriter() {}
            virtual bool WriteFile(const string& path, string content, string* err) = 0;
        };
        
        ManifestWriter(State* state, FileWriter* file_writer);
        
        bool Write(const string& filename, string* err);
    private:
        bool WriteBindings(BindingEnv& env);
        bool WritePool(string name, Pool* pool, string* err);
        bool WriteRule(string name, const Rule* rule, string* err);
        bool WriteEdge(Edge* edge, string* err);
        
        string content_;
        State* state_;
        FileWriter* file_writer_;
    };
    
}; /*namespace ninja*/

#endif // NINJA_MANIFEST_WRITER_H_
